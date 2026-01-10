# Jenkins Pipeline for EKS

This guide explains how to use Jenkins to build, test, and deploy your application to Amazon EKS (Elastic Kubernetes Service).

## Overview

This setup uses standard Kubernetes resources that work perfectly on EKS:
- **Deployment** - Manages application pods
- **Service** - Exposes the application internally
- **Ingress** - Routes external traffic (using NGINX Ingress Controller)
- **Namespace** - Organizes resources

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                          │
│              (Your source code + K8s manifests)              │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Jenkins polls or webhook
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Jenkins (on EKS or EC2)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Run Tests    │→ │ Build Image  │→ │ Push DockerHub│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐                                          │
│  │ Deploy to    │                                          │
│  │ EKS Cluster  │                                          │
│  └──────────────┘                                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Deploys via kubectl
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              EKS Cluster                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Deployment   │→ │ Service      │→ │ Ingress      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│              Your Application Running                         │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [ ] EKS cluster running and accessible
- [ ] `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- [ ] Jenkins installed (on EKS, EC2, or locally)
- [ ] Access to Jenkins UI
- [ ] GitHub repository with your code
- [ ] Docker Hub account
- [ ] NGINX Ingress Controller installed (optional, for Ingress)
- [ ] AWS Load Balancer Controller installed (if using LoadBalancer service type)

## Step 1: Install Jenkins on EKS

### Option A: Install Jenkins via Helm (Recommended)

```bash
# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create namespace
kubectl create namespace jenkins

# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.serviceType=ClusterIP \
  --wait

# Get Jenkins admin password
kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
echo

# Get Jenkins URL
kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo
```

### Option B: Install Jenkins on EC2 or Local Machine

If Jenkins is not on EKS, ensure:
- Jenkins has network access to your EKS cluster
- `kubectl` is installed and configured on Jenkins
- AWS credentials are configured (if using IRSA, configure service account)

## Step 2: Configure Jenkins for EKS Access

### Verify kubectl Access

Jenkins needs to be able to run `kubectl` commands against your EKS cluster.

**If Jenkins is on EKS:**
- Jenkins pod automatically has access via service account
- Grant RBAC permissions (see below)

**If Jenkins is on EC2 or external:**
- Ensure `kubectl` is installed: `kubectl version --client`
- Configure kubeconfig: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- Test access: `kubectl get nodes`

### Grant Jenkins Permissions

Jenkins needs permissions to deploy to your application namespace:

```bash
# Set variables
JENKINS_NS="jenkins"
TARGET_NS="cicd-app"

# Create role binding for Jenkins service account
 k create ns cicd-app
 
kubectl create rolebinding jenkins-deploy \
  --clusterrole=edit \
  --serviceaccount=jenkins:jenkins \
  --namespace=cicd-app \
  --dry-run=client -o yaml | kubectl apply -f -

# Or grant cluster-wide permissions (for learning, not production)
kubectl create clusterrolebinding jenkins-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=${JENKINS_NS}:jenkins \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Note**: For production, use least-privilege RBAC. For learning, cluster-admin is simpler.

### Verify Jenkins Can Access EKS

```bash
# If Jenkins is on EKS, test from Jenkins pod
JENKINS_POD=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}')

# Test kubectl access
kubectl exec -n jenkins jenkins -- kubectl get nodes
kubectl exec -n jenkins $JENKINS_POD -- kubectl get namespaces
```

## Step 3: Configure Jenkins Credentials

### Add Docker Hub Credentials

1. Jenkins UI → **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**

**For Docker Hub Username/Password:**
- **Kind**: Username with password
- **Scope**: Global
- **Username**: Your Docker Hub username
- **Password**: Your Docker Hub access token
- **ID**: `dockerhub-credentials`
- **Description**: Docker Hub credentials for pushing images
- Click **Create**

**For Docker Hub Username (as secret text):**
- **Kind**: Secret text
- **Scope**: Global
- **Secret**: Your Docker Hub username
- **ID**: `dockerhub-username`
- **Description**: Docker Hub username
- Click **Create**

### Add GitHub Credentials (If Private Repo)

If your repository is private:

1. **Add Credentials**
2. **Kind**: Secret text
3. **Secret**: GitHub Personal Access Token
4. **ID**: `github-token`
5. Click **Create**

## Step 4: Install Required Jenkins Plugins

1. Jenkins UI → **Manage Jenkins** → **Manage Plugins**
2. Go to **Available** tab
3. Install these plugins:
   - ✅ **Pipeline** (usually pre-installed)
   - ✅ **Git** (usually pre-installed)
   - ✅ **Docker Pipeline** (install if missing)
   - ✅ **Kubernetes CLI** (optional, for kubectl integration)
4. **Restart Jenkins if prompted**

## Step 5: Update Configuration Files

### Update EKS Manifests

Edit the files in `jenkins/eks/`:

1. **Update `deployment.yaml`**:
   - Replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username

2. **Update `ingress.yaml`** (optional):
   - Replace `cicd-app.example.com` with your domain
   - Or remove the `host` field to use default ingress IP
   - Uncomment External DNS annotations if using External DNS
   - Uncomment cert-manager annotations if using cert-manager

### Update Jenkinsfile

The main `Jenkinsfile` in `jenkins/` directory should work with EKS. Verify:

- Docker Hub credentials ID matches what you created
- Namespace is correct (`cicd-app`)
- Image name is correct
- Deployment path points to `jenkins/eks/` directory

## Step 6: Create Jenkins Pipeline Job

### Method 1: From Jenkinsfile in Git (Recommended)

1. Jenkins UI → **New Item**
2. Enter name: `cicd-app-pipeline-eks`
3. Select **Pipeline**
4. Click **OK**

**Configure:**
- **Description**: CI/CD pipeline for Python app on EKS
- **Pipeline** section:
  - **Definition**: Pipeline script from SCM
  - **SCM**: Git
  - **Repository URL**: Your GitHub repo URL
  - **Credentials**: Select GitHub token (if private repo)
  - **Branches to build**: `*/main` (or your branch)
  - **Script Path**: `CICD/jenkins/Jenkinsfile` (or create EKS-specific one)
- Click **Save**

### Method 2: Manual Pipeline Script

1. Create pipeline job as above
2. **Definition**: Pipeline script
3. Copy contents of `jenkins/Jenkinsfile` into script box
4. Modify the deploy stage to use `jenkins/eks/` directory
5. Click **Save**

## Step 7: Modify Jenkinsfile for EKS

Update the deployment stage in your Jenkinsfile to use EKS manifests:

```groovy
stage('Deploy to EKS') {
    steps {
        script {
            echo "Deploying to EKS namespace: ${NAMESPACE}"
            
            // Create namespace
            sh """
                kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            """
            
            // Update and apply manifests
            dir('CICD/jenkins/eks') {
                sh """
                    # Update image in deployment.yaml
                    perl -i -pe "s|image:.*${IMAGE_NAME}.*|image: ${FULL_IMAGE_NAME}|g" deployment.yaml
                    
                    # Update APP_VERSION with build number
                    perl -i -pe "s|(name: APP_VERSION\\s+value: )\".*\"|\1\"${env.BUILD_NUMBER}\"|g" deployment.yaml || true
                    
                    # Apply manifests
                    kubectl apply -f namespace.yaml
                    kubectl apply -f deployment.yaml
                    kubectl apply -f service.yaml
                    
                    # Apply ingress if it exists
                    if [ -f ingress.yaml ]; then
                        kubectl apply -f ingress.yaml
                    fi
                """
            }
            
            // Wait for rollout
            sh """
                kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=5m || true
            """
        }
    }
}
```

## Step 8: Run the Pipeline

1. Go to Jenkins → Your pipeline job
2. Click **Build Now**
3. Watch the pipeline run:
   - **Checkout**: Gets code from Git
   - **Test**: Runs Python tests
   - **Build**: Builds Docker image
   - **Security Scan**: Scans for vulnerabilities
   - **Push**: Pushes to Docker Hub
   - **Deploy**: Deploys to EKS

## Step 9: Verify Deployment

```bash
# Check namespace
kubectl get namespace cicd-app

# Check deployment
kubectl get deployment -n cicd-app

# Check pods
kubectl get pods -n cicd-app

# Check service
kubectl get svc -n cicd-app

# Check ingress (if using)
kubectl get ingress -n cicd-app

# Get ingress URL
kubectl get ingress cicd-app -n cicd-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo

# Or get ingress IP
kubectl get ingress cicd-app -n cicd-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo

# Test the application
# If using ingress with domain:
curl http://cicd-app.example.com/

# If using ingress IP:
INGRESS_IP=$(kubectl get ingress cicd-app -n cicd-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/

# Or port-forward for testing
kubectl port-forward -n cicd-app svc/cicd-app 8080:80
curl http://localhost:8080/
```

## Step 10: Access Jenkins (If on EKS)

### Get Jenkins URL

```bash
# If using LoadBalancer
kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo

# Or use port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Access: http://localhost:8080
```

### Get Jenkins Admin Password

```bash
kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
echo
```

## Jenkins Pipeline Stages Explained

### 1. Checkout
- Gets code from Git repository

### 2. Test
- Creates Python virtual environment
- Installs dependencies
- Runs unit tests with pytest
- Runs linting with flake8

### 3. Build Docker Image
- Builds Docker image using Dockerfile
- Tags with branch name and build number

### 4. Security Scan
- Uses Trivy to scan for vulnerabilities
- Non-blocking (won't fail pipeline)

### 5. Push to Docker Hub
- Logs into Docker Hub
- Pushes image with tags

### 6. Deploy to EKS
- Creates namespace if it doesn't exist
- Updates deployment with new image
- Applies Kubernetes manifests
- Waits for rollout to complete

## Setting Up Webhooks (Optional)

To trigger builds automatically on Git push:

### Step 1: Get Jenkins Webhook URL

```bash
# Get Jenkins URL
JENKINS_URL=$(kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Webhook URL format:
echo "http://${JENKINS_URL}/github-webhook/"
```

### Step 2: Configure GitHub Webhook

1. GitHub repo → **Settings** → **Webhooks**
2. Click **Add webhook**
3. **Payload URL**: `http://<jenkins-url>/github-webhook/`
4. **Content type**: `application/json`
5. **Events**: Just the push event
6. Click **Add webhook**

### Step 3: Configure Jenkins Job

1. Pipeline job → **Configure**
2. **Build Triggers** section:
   - Check **GitHub hook trigger for GITScm polling**
3. Click **Save**

Now, every push to your repo will trigger a Jenkins build!

## Troubleshooting

### Jenkins Not Accessible

```bash
# Check Jenkins pod
kubectl get pods -n jenkins

# Check Jenkins service
kubectl get svc -n jenkins

# Check Jenkins logs
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller --tail=50
```

### Pipeline Failing at Docker Build

**Issue**: Docker daemon not available in Jenkins pod

**Solution**: 
- If Jenkins is on EKS, use Docker-in-Docker or Kaniko
- Or build on external Jenkins with Docker installed
- Or use AWS CodeBuild for building images

### Pipeline Failing at EKS Deploy

**Issue**: Permission denied or kubectl not found

**Solution**: 

```bash
# Verify kubectl is available
kubectl exec -n jenkins <jenkins-pod> -- kubectl version --client

# Grant permissions
kubectl create clusterrolebinding jenkins-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=jenkins:jenkins
```

### Image Pull Errors

**Issue**: Can't pull image from Docker Hub

**Solution**: 
1. Verify Docker Hub credentials in Jenkins
2. Check image exists: `docker pull YOUR_USERNAME/cicd-learning-app:latest`
3. If using private image, create image pull secret in EKS:

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN \
  --docker-email=YOUR_EMAIL \
  -n cicd-app

# Update deployment to use secret
kubectl patch deployment cicd-app -n cicd-app -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"dockerhub-secret"}]}}}}'
```

### Ingress Not Working

**Issue**: Ingress not creating LoadBalancer

**Solution**:
1. Verify NGINX Ingress Controller is installed:
   ```bash
   kubectl get pods -n ingress-nginx
   ```

2. Check ingress status:
   ```bash
   kubectl describe ingress cicd-app -n cicd-app
   ```

3. Verify AWS Load Balancer Controller (if using ALB/NLB):
   ```bash
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   ```

### Application Not Accessible

**Issue**: Can't reach the application

**Solution**:

```bash
# Check pods are running
kubectl get pods -n cicd-app

# Check pod logs
kubectl logs -n cicd-app -l app=cicd-app

# Check service endpoints
kubectl get endpoints -n cicd-app cicd-app

# Test via port-forward
kubectl port-forward -n cicd-app svc/cicd-app 8080:80
curl http://localhost:8080/
```

## Using Ingress vs LoadBalancer

### Option 1: Ingress (Recommended)

- Uses NGINX Ingress Controller
- Single LoadBalancer for multiple services
- Path-based routing
- TLS termination

**Use when**: You have multiple services or want path-based routing

### Option 2: LoadBalancer Service

- Direct AWS LoadBalancer per service
- Simpler configuration
- More expensive (one LB per service)

**Use when**: You have a single service or want direct access

To use LoadBalancer, change `service.yaml`:

```yaml
spec:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

## Advanced: Using External DNS and cert-manager

### External DNS

Automatically creates Route53 records for your ingress:

1. Install External DNS (see EKS setup docs)
2. Uncomment External DNS annotation in `ingress.yaml`
3. Update hostname to your domain

### cert-manager

Automatically provisions TLS certificates:

1. Install cert-manager (see EKS setup docs)
2. Create ClusterIssuer
3. Uncomment cert-manager annotation in `ingress.yaml`
4. Uncomment TLS section in `ingress.yaml`

## Comparison: EKS vs OpenShift

| Feature | EKS | OpenShift |
|---------|-----|-----------|
| **Deployment** | Deployment | DeploymentConfig |
| **Networking** | Ingress | Route |
| **Image Registry** | External (Docker Hub) | ImageStream |
| **CLI** | kubectl | oc (or kubectl) |
| **Portability** | ✅ Standard K8s | ⚠️ OpenShift-specific features |
| **Learning** | Standard K8s | OpenShift-specific |

**For learning**: EKS uses standard Kubernetes, making it more portable.

## Next Steps

1. Run your first successful pipeline
2. Set up webhooks for automatic builds
3. Experiment with different pipeline stages
4. Add External DNS for automatic domain management
5. Add cert-manager for automatic TLS
6. Set up monitoring and logging
7. Explore AWS CodeBuild/CodePipeline integration

## Additional Resources

- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

Happy Learning! 🚀
