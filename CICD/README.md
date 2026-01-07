# CI/CD Pipeline with GitHub Actions and ArgoCD

Complete CI/CD pipeline setup for learning and hands-on experience with modern DevOps practices.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                          │
│              (Your source code + K8s manifests)              │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Push/PR triggers
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions (CI)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Run Tests    │→ │ Build Image  │→ │ Push DockerHub│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Security Scan│→ │ Update Manifests│                     │
│  └──────────────┘  └──────────────┘                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Commits updated manifests
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Docker Hub                                       │
│              Container Registry                               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ ArgoCD watches Git
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              ArgoCD (GitOps)                                  │
│  Detects Git changes → Syncs to EKS cluster                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Deploys
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              EKS Cluster                                      │
│              Your Application Running                         │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
CICD/
├── app/                          # Python application
│   ├── app.py                   # Flask application
│   ├── test_app.py              # Unit tests
│   ├── requirements.txt         # Python dependencies
│   └── Dockerfile               # Container image definition
├── k8s-manifests/               # Kubernetes manifests (GitOps repo)
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── argocd/                       # ArgoCD configuration
│   └── application.yaml         # ArgoCD Application definition
└── .github/workflows/            # GitHub Actions workflows
    └── ci-cd.yml                # Main CI/CD pipeline
```

## Prerequisites

### 1. GitHub Setup

- GitHub account
- Repository created (or use existing)
- GitHub Actions enabled

### 2. Docker Hub Setup

- Docker Hub account
- Create repository: `cicd-learning-app`

### 3. EKS Cluster

- EKS cluster running (from your Terraform setup)
- `kubectl` configured
- ArgoCD installed (see installation guide below)

## Setup Instructions

### Step 1: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

1. **DOCKERHUB_USERNAME**: Your Docker Hub username
2. **DOCKERHUB_TOKEN**: Docker Hub access token
   - Create at: https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Give it read/write permissions

### Step 2: Update Configuration Files

#### Update `k8s-manifests/deployment.yaml`

Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username:

```yaml
image: YOUR_DOCKERHUB_USERNAME/cicd-learning-app:latest
```

#### Update `argocd/application.yaml`

Replace repository URL:

```yaml
repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
```

#### Update `ingress.yaml` (optional)

If using External DNS and cert-manager, uncomment and configure:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: cicd-app.example.com
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### Step 3: Install ArgoCD

See [INSTALL-ARGOCD.md](./INSTALL-ARGOCD.md) for detailed instructions.

Quick install:

```bash
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
kubectl create namespace argocd
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.6.0 \
  --wait

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (username: admin)
```

### Step 4: Configure ArgoCD Repository

ArgoCD needs access to your GitHub repository:

#### Option A: Public Repository (Easiest)

If your repo is public, no additional setup needed.

#### Option B: Private Repository

1. Create GitHub Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens
   - Generate token with `repo` scope

2. Add repository to ArgoCD:

```bash
# Using ArgoCD CLI
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN \
  --type git

# Or via UI: Settings → Repositories → Connect Repo
```

### Step 5: Create ArgoCD Application

Apply the ArgoCD Application:

```bash
# Update application.yaml with your repo URL first
kubectl apply -f argocd/application.yaml
```

Or create via ArgoCD UI:
1. Go to ArgoCD UI (https://localhost:8080)
2. Click "New App"
3. Fill in:
   - Application Name: `cicd-app`
   - Project: `default`
   - Repository URL: Your GitHub repo
   - Path: `CICD/k8s-manifests`
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `cicd-app`
4. Enable "Auto-Create Namespace"
5. Enable "Auto-Sync"
6. Click "Create"

### Step 6: Test the Pipeline

1. **Make a change to the app**:
   ```bash
   # Edit app/app.py
   # Change the welcome message
   ```

2. **Commit and push**:
   ```bash
   git add .
   git commit -m "test: update app message"
   git push origin main
   ```

3. **Watch GitHub Actions**:
   - Go to your repo → Actions tab
   - Watch the workflow run

4. **Watch ArgoCD**:
   - ArgoCD will detect the Git change
   - Application will sync automatically
   - Check deployment status

5. **Test the app**:
   ```bash
   # Port-forward to access the app
   kubectl port-forward -n cicd-app svc/cicd-app 8080:80
   
   # Test endpoints
   curl http://localhost:8080/
   curl http://localhost:8080/health
   curl http://localhost:8080/api/hello?name=Test
   ```

## Pipeline Workflow

### On Push to Main/Develop

1. **Test Job**: Runs unit tests
2. **Build Job**: Builds Docker image
3. **Security Scan**: Scans image for vulnerabilities
4. **Update Manifests**: Updates image tag in K8s manifests
5. **Git Commit**: Commits updated manifests
6. **ArgoCD Sync**: Detects change and deploys to cluster

### On Pull Request

1. **Test Job**: Runs unit tests only
2. No deployment (manifests not updated)

## Testing Locally

### Run Tests

```bash
cd CICD/app
pip install -r requirements.txt
pip install pytest pytest-cov
python -m pytest test_app.py -v
```

### Build Docker Image

```bash
cd CICD/app
docker build -t cicd-learning-app:test .
docker run -p 5000:5000 cicd-learning-app:test
```

### Test Endpoints

```bash
curl http://localhost:5000/
curl http://localhost:5000/health
curl http://localhost:5000/api/hello?name=Test
curl -X POST http://localhost:5000/api/echo -H "Content-Type: application/json" -d '{"test": "data"}'
```

## Monitoring the Pipeline

### GitHub Actions

- View workflow runs: Repository → Actions tab
- View logs: Click on a workflow run
- Re-run failed jobs: Click "Re-run jobs"

### ArgoCD

- View applications: ArgoCD UI → Applications
- View sync status: Green = synced, Yellow = out of sync
- View logs: Click application → Logs tab
- View resources: Click application → Resources tab

### Kubernetes

```bash
# Check deployment status
kubectl get deployment -n cicd-app

# Check pods
kubectl get pods -n cicd-app

# View logs
kubectl logs -n cicd-app -l app=cicd-app

# Check service
kubectl get svc -n cicd-app
```

## Troubleshooting

### GitHub Actions Issues

**Tests failing:**
- Check test output in Actions tab
- Run tests locally to debug

**Docker push failing:**
- Verify Docker Hub credentials in Secrets
- Check image name matches Docker Hub repo

**Manifest update failing:**
- Check GITHUB_TOKEN has write permissions
- Verify branch protection rules allow automation

### ArgoCD Issues

**Application not syncing:**
- Check repository access (public or credentials configured)
- Verify path to manifests is correct
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`

**Sync failing:**
- Check Kubernetes manifests are valid: `kubectl apply --dry-run=client -f k8s-manifests/`
- Verify namespace exists or auto-create is enabled
- Check resource quotas

**Image pull errors:**
- Verify Docker Hub image exists
- Check image pull secrets if using private registry
- Verify image tag is correct

## Next Steps

1. **Add Environments**: Create dev/staging/prod environments
2. **Add Monitoring**: Integrate Prometheus/Grafana
3. **Add Notifications**: Slack/Email notifications on deployments
4. **Add Rollback**: Implement rollback strategies
5. **Add Canary Deployments**: Gradual rollout with ArgoCD Rollouts

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Learning Objectives Achieved

✅ CI/CD pipeline concepts  
✅ GitHub Actions workflows  
✅ Docker containerization  
✅ Automated testing  
✅ Security scanning  
✅ GitOps with ArgoCD  
✅ Kubernetes deployments  
✅ Infrastructure as Code  

Happy Learning! 🚀

