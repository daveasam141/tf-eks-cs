# Installing ArgoCD on EKS

This guide walks you through installing ArgoCD on your EKS cluster for GitOps deployments.

## Prerequisites

- EKS cluster is running and accessible
- `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- `helm` installed (version 3.x)

## Installation Steps

### Step 1: Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Step 2: Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

### Step 3: Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.6.0 \
  --set server.service.type=LoadBalancer \
  --set server.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait \
  --timeout 10m
```

**What this does:**
- Installs ArgoCD with all components
- Creates LoadBalancer service for UI access
- Uses AWS NLB (Network Load Balancer)

### Step 4: Get ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

**Save this password!** You'll need it to log in.

### Step 5: Access ArgoCD UI

#### Option A: Via LoadBalancer (Recommended)

```bash
# Get the LoadBalancer address
kubectl get svc argocd-server -n argocd

# Wait for EXTERNAL-IP to be assigned (takes 1-2 minutes)
# Then access: https://<EXTERNAL-IP>
```

**Note:** ArgoCD uses HTTPS. You may need to accept the self-signed certificate.

#### Option B: Via Port-Forward (For Testing)

```bash
# Port-forward to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: (from Step 4)
```

### Step 6: Install ArgoCD CLI (Optional but Recommended)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Verify
argocd version --client
```

### Step 7: Login via CLI

```bash
# Get ArgoCD server address
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Login (use admin password from Step 4)
argocd login $ARGOCD_SERVER --username admin --insecure

# Or if using port-forward
argocd login localhost:8080 --username admin --insecure
```

## Verify Installation

### Check Pods

```bash
kubectl get pods -n argocd
```

Expected output:
```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-xxx                   1/1     Running   0          5m
argocd-applicationset-controller-xxx                1/1     Running   0          5m
argocd-dex-server-xxx                               1/1     Running   0          5m
argocd-notifications-controller-xxx                 1/1     Running   0          5m
argocd-redis-xxx                                    1/1     Running   0          5m
argocd-repo-server-xxx                              1/1     Running   0          5m
argocd-server-xxx                                   1/1     Running   0          5m
```

### Check Services

```bash
kubectl get svc -n argocd
```

### Access UI

Open ArgoCD UI in browser and verify you can log in.

## Configure ArgoCD

### Add GitHub Repository

#### For Public Repository

No credentials needed. Just use the repository URL in your Application.

#### For Private Repository

**Option 1: Via UI**

1. Go to ArgoCD UI → Settings → Repositories
2. Click "Connect Repo"
3. Fill in:
   - Type: `git`
   - Repository URL: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
   - Username: Your GitHub username
   - Password: GitHub Personal Access Token
4. Click "Connect"

**Option 2: Via CLI**

```bash
# Create GitHub Personal Access Token first
# GitHub → Settings → Developer settings → Personal access tokens

# Add repository
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN \
  --type git
```

### Create Application

#### Option 1: Via UI

1. Click "New App"
2. Fill in:
   - **Application Name**: `cicd-app`
   - **Project**: `default`
   - **Repository URL**: Your GitHub repo
   - **Path**: `CICD/k8s-manifests`
   - **Cluster**: `https://kubernetes.default.svc`
   - **Namespace**: `cicd-app`
3. Under "Sync Policy":
   - Enable "Auto-Create Namespace"
   - Enable "Auto-Sync"
   - Enable "Self-Heal"
   - Enable "Prune"
4. Click "Create"

#### Option 2: Via CLI

```bash
argocd app create cicd-app \
  --repo https://github.com/YOUR_USERNAME/YOUR_REPO.git \
  --path CICD/k8s-manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace cicd-app \
  --sync-policy automated \
  --self-heal \
  --auto-prune
```

#### Option 3: Via YAML (Recommended)

```bash
# Update application.yaml with your repo URL
kubectl apply -f argocd/application.yaml
```

## Using ArgoCD

### View Applications

```bash
# List applications
argocd app list

# Get application details
argocd app get cicd-app

# View application status
argocd app get cicd-app --refresh
```

### Manual Sync

```bash
# Sync application manually
argocd app sync cicd-app

# Sync with specific revision
argocd app sync cicd-app --revision main

# Sync with prune (delete resources not in Git)
argocd app sync cicd-app --prune
```

### View Application Resources

```bash
# View application resources
argocd app resources cicd-app

# View application logs
argocd app logs cicd-app

# View application events
argocd app get cicd-app --refresh
```

### Rollback

```bash
# View application history
argocd app history cicd-app

# Rollback to previous version
argocd app rollback cicd-app <REVISION>
```

## ArgoCD Features

### Auto-Sync

Automatically syncs when changes are detected in Git.

### Self-Heal

Automatically corrects drift (if cluster state differs from Git).

### Prune

Deletes resources that are no longer in Git.

### Sync Windows

Configure when ArgoCD can sync:

```yaml
syncWindows:
- kind: allow
  schedule: '10 1 * * *'  # Allow syncs at 1:10 AM
  duration: 1h
  applications:
  - '*'
- kind: deny
  schedule: '0 22 * * *'  # Deny syncs at 10 PM
  duration: 8h
```

## Troubleshooting

### Check ArgoCD Pods

```bash
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd
kubectl logs <pod-name> -n argocd
```

### Check Application Status

```bash
# View application details
argocd app get cicd-app

# Check sync status
argocd app get cicd-app --refresh

# View application events
kubectl get events -n argocd --field-selector involvedObject.name=cicd-app
```

### Common Issues

**Application stuck in "Progressing"**
- Check if pods are starting: `kubectl get pods -n cicd-app`
- Check resource quotas: `kubectl describe quota -n cicd-app`
- Check application logs: `argocd app logs cicd-app`

**Sync failing**
- Verify repository access
- Check manifests are valid: `kubectl apply --dry-run=client -f k8s-manifests/`
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`

**Repository access denied**
- Verify credentials (for private repos)
- Check GitHub token has correct permissions
- Verify repository URL is correct

**Image pull errors**
- Check image exists in Docker Hub
- Verify image pull secrets if using private registry
- Check network connectivity

## Upgrading ArgoCD

```bash
# Check current version
helm list -n argocd

# Update repository
helm repo update

# Upgrade ArgoCD
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --reuse-values \
  --version 7.6.0
```

## Uninstalling ArgoCD

```bash
# Uninstall Helm release
helm uninstall argocd -n argocd

# Delete namespace (this removes all ArgoCD resources)
kubectl delete namespace argocd

# Note: Applications deployed by ArgoCD will remain in cluster
# Delete them manually if needed
```

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)

