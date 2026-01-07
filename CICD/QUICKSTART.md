# CI/CD Pipeline Quick Start

Quick setup guide to get your CI/CD pipeline running.

## Prerequisites Checklist

- [ ] EKS cluster running
- [ ] GitHub repository created
- [ ] Docker Hub account created
- [ ] `kubectl` configured
- [ ] `helm` installed

## Step 1: Configure GitHub Secrets

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

   - **Name**: `DOCKERHUB_USERNAME`  
     **Value**: Your Docker Hub username

   - **Name**: `DOCKERHUB_TOKEN`  
     **Value**: Docker Hub access token
     - Create at: https://hub.docker.com/settings/security
     - Click "New Access Token"
     - Name: `github-actions`
     - Permissions: Read & Write

## Step 2: Update Configuration Files

### Update `k8s-manifests/deployment.yaml`

Replace `YOUR_DOCKERHUB_USERNAME`:

```yaml
image: YOUR_DOCKERHUB_USERNAME/cicd-learning-app:latest
```

### Update `argocd/application.yaml`

Replace repository URL:

```yaml
repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
```

## Step 3: Create Docker Hub Repository

1. Go to https://hub.docker.com
2. Click **Create Repository**
3. Name: `cicd-learning-app`
4. Visibility: Public (or Private if you prefer)
5. Click **Create**

## Step 4: Install ArgoCD

```bash
# Add Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
kubectl create namespace argocd
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.6.0 \
  --set server.service.type=LoadBalancer \
  --set server.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

## Step 5: Configure ArgoCD Repository

### For Public Repository

No additional setup needed.

### For Private Repository

1. Create GitHub Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens
   - Generate token with `repo` scope

2. Add to ArgoCD (via UI):
   - Access ArgoCD UI (get LoadBalancer address)
   - Settings → Repositories → Connect Repo
   - Add your GitHub repo with token

## Step 6: Create ArgoCD Application

```bash
# Update application.yaml with your repo URL first
kubectl apply -f argocd/application.yaml
```

Or via UI:
1. ArgoCD UI → New App
2. Fill in details from `argocd/application.yaml`
3. Enable Auto-Sync

## Step 7: Test the Pipeline

1. **Make a change**:
   ```bash
   # Edit app/app.py - change welcome message
   ```

2. **Commit and push**:
   ```bash
   git add .
   git commit -m "test: update app"
   git push origin main
   ```

3. **Watch the magic**:
   - GitHub Actions tab → Watch workflow run
   - ArgoCD UI → Watch application sync
   - Check your app: `kubectl get pods -n cicd-app`

## Verify Everything Works

```bash
# Check GitHub Actions
# Go to repo → Actions tab

# Check ArgoCD
kubectl get application -n argocd

# Check deployment
kubectl get pods -n cicd-app

# Test the app
kubectl port-forward -n cicd-app svc/cicd-app 8080:80
curl http://localhost:8080/
```

## Troubleshooting

**GitHub Actions failing?**
- Check Secrets are set correctly
- Verify Docker Hub repo exists
- Check workflow logs

**ArgoCD not syncing?**
- Verify repository access
- Check application status: `argocd app get cicd-app`
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`

**App not deploying?**
- Check pods: `kubectl get pods -n cicd-app`
- Check logs: `kubectl logs -n cicd-app -l app=cicd-app`
- Verify image exists: `docker pull YOUR_USERNAME/cicd-learning-app:latest`

## Next Steps

- Read [README.md](./README.md) for detailed documentation
- Read [INSTALL-ARGOCD.md](./INSTALL-ARGOCD.md) for ArgoCD details
- Experiment with the pipeline!

Happy Learning! 🚀

