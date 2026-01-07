# CI/CD Setup Checklist

Use this checklist to ensure everything is configured correctly.

## Pre-Setup

- [ ] EKS cluster is running and accessible
- [ ] `kubectl` is configured: `kubectl cluster-info`
- [ ] `helm` is installed: `helm version`
- [ ] GitHub account and repository created
- [ ] Docker Hub account created

## GitHub Configuration

- [ ] Repository created and code pushed
- [ ] GitHub Actions enabled (enabled by default)
- [ ] Secret `DOCKERHUB_USERNAME` added
- [ ] Secret `DOCKERHUB_TOKEN` added
- [ ] Repository is public OR Personal Access Token created for ArgoCD

## Docker Hub Configuration

- [ ] Repository `cicd-learning-app` created
- [ ] Repository is public OR access token configured
- [ ] Verified you can push to repository

## File Updates Required

- [ ] Updated `k8s-manifests/deployment.yaml`:
  - [ ] Replaced `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username

- [ ] Updated `argocd/application.yaml`:
  - [ ] Replaced `YOUR_USERNAME/YOUR_REPO` with your GitHub repo URL

- [ ] Updated `k8s-manifests/ingress.yaml` (optional):
  - [ ] Changed `cicd-app.example.com` to your domain (if using External DNS)

## ArgoCD Installation

- [ ] ArgoCD installed via Helm
- [ ] ArgoCD admin password retrieved
- [ ] ArgoCD UI accessible (via LoadBalancer or port-forward)
- [ ] Logged into ArgoCD UI
- [ ] GitHub repository added to ArgoCD (if private repo)

## ArgoCD Application

- [ ] Application created (via YAML or UI)
- [ ] Application shows as "Synced" and "Healthy"
- [ ] Auto-sync enabled
- [ ] Self-heal enabled (optional but recommended)

## First Pipeline Run

- [ ] Pushed code to trigger GitHub Actions
- [ ] GitHub Actions workflow completed successfully
- [ ] Docker image pushed to Docker Hub
- [ ] Kubernetes manifests updated in Git
- [ ] ArgoCD detected changes and synced
- [ ] Application pods running: `kubectl get pods -n cicd-app`
- [ ] Application accessible and responding

## Verification Commands

Run these to verify everything works:

```bash
# Check GitHub Actions
# Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/actions

# Check Docker Hub
# Go to: https://hub.docker.com/r/YOUR_USERNAME/cicd-learning-app

# Check ArgoCD
kubectl get application -n argocd
argocd app get cicd-app

# Check Kubernetes resources
kubectl get all -n cicd-app

# Test the application
kubectl port-forward -n cicd-app svc/cicd-app 8080:80
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/api/hello?name=Test
```

## Common Issues

### GitHub Actions

- **Workflow not running**: Check if Actions are enabled in repo settings
- **Docker push failing**: Verify secrets are correct
- **Tests failing**: Run tests locally to debug

### ArgoCD

- **Application not syncing**: Check repository access
- **Sync failing**: Check manifests are valid
- **Pods not starting**: Check image exists in Docker Hub

### Application

- **404 errors**: Check service and ingress configuration
- **Image pull errors**: Verify image name and tag
- **Health check failing**: Check application logs

## Next Steps After Setup

1. Make changes to the app and watch the pipeline
2. Experiment with different branches
3. Add more features to the application
4. Set up monitoring and logging
5. Implement multi-environment deployments

## Getting Help

- Check [README.md](./README.md) for detailed documentation
- Check [INSTALL-ARGOCD.md](./INSTALL-ARGOCD.md) for ArgoCD help
- Review GitHub Actions logs
- Check ArgoCD application events
- Review Kubernetes pod logs

