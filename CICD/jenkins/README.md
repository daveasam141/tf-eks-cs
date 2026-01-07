# Jenkins Pipeline for OpenShift

This guide explains how to use Jenkins (installed via OpenShift Software Catalog) to build, test, and deploy your application to OpenShift.

## Overview

**Yes, native Kubernetes resources work on OpenShift!** OpenShift is built on Kubernetes and supports all standard K8s resources. However, OpenShift also provides additional features like:
- **Routes** (instead of Ingress)
- **DeploymentConfigs** (OpenShift-native deployments)
- **ImageStreams** (internal image registry)
- **BuildConfigs** (OpenShift-native builds)

You can use either standard K8s resources OR OpenShift-native resources - both work!

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Jenkins polls or webhook
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Jenkins (on OpenShift)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Run Tests    │→ │ Build Image  │→ │ Push DockerHub│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐                                          │
│  │ Deploy to    │                                          │
│  │ OpenShift    │                                          │
│  └──────────────┘                                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Deploys
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              OpenShift Cluster                                │
│              Your Application Running                         │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [ ] Jenkins installed via OpenShift Software Catalog or Helm
- [ ] Access to Jenkins UI
- [ ] GitHub repository with your code
- [ ] Docker Hub account
- [ ] OpenShift CLI (`oc`) installed and configured (for setup, not required in Jenkins)

## How Jenkins Connects to OpenShift

**Important**: Jenkins automatically connects to the OpenShift cluster it's running on!

- Jenkins uses the **service account token** for authentication
- No manual `oc login` needed
- Uses `oc` CLI if available, or `kubectl` as fallback (both work with OpenShift!)
- Just need to grant RBAC permissions (see setup guide)

**Note**: If `oc` CLI is not installed in Jenkins pod, the Jenkinsfile automatically uses `kubectl`, which works perfectly with OpenShift!

See [OPENSHIFT-CONNECTION.md](./OPENSHIFT-CONNECTION.md) for detailed explanation.

## Step 1: Access Jenkins

### Find Jenkins URL

```bash
# Get Jenkins route
oc get route -n <jenkins-namespace> | grep jenkins

# Or check in OpenShift UI:
# Networking → Routes → Find jenkins route
```

### Get Jenkins Admin Password

```bash
# Get Jenkins admin password from OpenShift secret
oc get secret jenkins -n <jenkins-namespace> -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
echo
```

### Login to Jenkins

1. Open Jenkins URL in browser
2. Username: `admin` (or check OpenShift secret for username)
3. Password: (from command above)

## Step 2: Configure Jenkins Credentials

### Add Docker Hub Credentials

1. Jenkins UI → **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials** → **Add Credentials**
3. Fill in:
   - **Kind**: Username with password
   - **Scope**: Global
   - **Username**: Your Docker Hub username
   - **Password**: Your Docker Hub access token
   - **ID**: `dockerhub-credentials`
   - **Description**: Docker Hub credentials
4. Click **Create**

### Add Docker Hub Username (for image naming)

1. **Add Credentials** again
2. Fill in:
   - **Kind**: Secret text
   - **Scope**: Global
   - **Secret**: Your Docker Hub username
   - **ID**: `dockerhub-username`
   - **Description**: Docker Hub username
3. Click **Create**

### Verify OpenShift Access

Jenkins should already have access to OpenShift (since it's running in OpenShift). Verify:

```bash
# From Jenkins pod or your local machine
oc whoami
oc get projects
```

## Step 3: Create Jenkins Pipeline

### Option A: Create Pipeline Job (Recommended)

1. Jenkins UI → **New Item**
2. Enter name: `cicd-app-pipeline`
3. Select **Pipeline**
4. Click **OK**

### Configure Pipeline

1. **Pipeline Definition**: Select "Pipeline script from SCM"
2. **SCM**: Git
3. **Repository URL**: Your GitHub repository URL
4. **Credentials**: Add if private repo (GitHub token)
5. **Branches to build**: `*/main` (or your branch)
6. **Script Path**: `CICD/jenkins/Jenkinsfile`
7. Click **Save**

### Option B: Use Jenkinsfile Directly

1. Jenkins UI → **New Item**
2. Enter name: `cicd-app-pipeline`
3. Select **Pipeline**
4. In **Pipeline** section:
   - **Definition**: Pipeline script
   - **Script**: Copy contents of `Jenkinsfile`
5. Click **Save**

## Step 4: Update Configuration Files

### Update Jenkinsfile

Edit `jenkins/Jenkinsfile` and verify:
- Docker Hub credentials ID matches what you created
- Namespace is correct
- Image name is correct

### Update OpenShift Manifests

#### For Standard Kubernetes Resources (Works on OpenShift)

Use the existing `k8s-manifests/` directory. These work perfectly on OpenShift!

#### For OpenShift-Native Resources (Optional)

If you want to use OpenShift-specific features:

1. **Update `openshift/deploymentconfig.yaml`**:
   - Replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username

2. **Update `openshift/imagestream.yaml`** (if using ImageStreams):
   - Replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username

## Step 5: Choose Your Deployment Approach

### Approach 1: Standard Kubernetes Resources (Recommended for Learning)

Use the existing `k8s-manifests/` directory. These work on OpenShift:

- `deployment.yaml` (works on OpenShift)
- `service.yaml` (works on OpenShift)
- `ingress.yaml` (works, but Routes are preferred on OpenShift)

**Advantages:**
- Portable (works on any K8s cluster)
- Standard Kubernetes knowledge
- Simpler

### Approach 2: OpenShift-Native Resources

Use `jenkins/openshift/` directory:

- `deploymentconfig.yaml` (OpenShift-native)
- `route.yaml` (OpenShift-native, better than Ingress)
- `imagestream.yaml` (optional, for OpenShift registry)

**Advantages:**
- OpenShift-specific features
- Routes are simpler than Ingress
- ImageStreams for internal registry

**My Recommendation**: Start with standard K8s resources, then explore OpenShift-native features.

## Step 6: Run the Pipeline

1. Go to Jenkins → Your pipeline job
2. Click **Build Now**
3. Watch the pipeline run:
   - **Checkout**: Gets code from Git
   - **Test**: Runs Python tests
   - **Build**: Builds Docker image
   - **Security Scan**: Scans for vulnerabilities
   - **Push**: Pushes to Docker Hub
   - **Deploy**: Deploys to OpenShift

## Step 7: Verify Deployment

```bash
# Check deployment
oc get deployment -n cicd-app
oc get pods -n cicd-app

# Check service
oc get svc -n cicd-app

# Check route (if using Routes)
oc get route -n cicd-app

# Get route URL
oc get route cicd-app -n cicd-app -o jsonpath='{.spec.host}'

# Test the application
curl http://$(oc get route cicd-app -n cicd-app -o jsonpath='{.spec.host}')/
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

### 6. Deploy to OpenShift
- Creates/updates OpenShift project
- Updates deployment with new image
- Applies Kubernetes/OpenShift manifests
- Waits for rollout to complete

## Using Routes Instead of Ingress

OpenShift Routes are simpler than Ingress. Example:

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: cicd-app
spec:
  to:
    kind: Service
    name: cicd-app
  port:
    targetPort: http
```

**Advantages of Routes:**
- Simpler configuration
- Automatic HTTPS (optional)
- Built into OpenShift
- No need for Ingress Controller

## Troubleshooting

### Jenkins Not Accessible

```bash
# Check Jenkins pod status
oc get pods -n <jenkins-namespace>

# Check Jenkins route
oc get route -n <jenkins-namespace>

# Check Jenkins service
oc get svc -n <jenkins-namespace>
```

### Pipeline Failing

**Check Jenkins logs:**
- Jenkins UI → Your pipeline → Console Output
- Look for error messages

**Common issues:**
- Docker Hub credentials incorrect
- OpenShift permissions (check `oc whoami`)
- Image pull errors
- Namespace doesn't exist

### Deployment Not Working

```bash
# Check deployment status
oc describe deployment cicd-app -n cicd-app

# Check pod logs
oc logs -n cicd-app -l app=cicd-app

# Check events
oc get events -n cicd-app --sort-by='.lastTimestamp'
```

### OpenShift Permissions

If Jenkins can't deploy, grant permissions:

```bash
# Grant edit role to Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:<jenkins-namespace>:jenkins -n cicd-app
```

## Advanced: Using ImageStreams

If you want to use OpenShift's internal registry:

1. Create ImageStream:
```bash
oc apply -f jenkins/openshift/imagestream.yaml
```

2. Import image from Docker Hub:
```bash
oc import-image cicd-app:latest \
  --from=YOUR_DOCKERHUB_USERNAME/cicd-learning-app:latest \
  --confirm -n cicd-app
```

3. Update DeploymentConfig to use ImageStream:
```yaml
image: cicd-app:latest  # Instead of Docker Hub URL
```

## Comparison: Standard K8s vs OpenShift-Native

| Feature | Standard K8s | OpenShift-Native |
|---------|--------------|------------------|
| **Deployment** | Deployment | DeploymentConfig |
| **Networking** | Ingress | Route |
| **Image Registry** | External (Docker Hub) | ImageStream |
| **Portability** | ✅ Works everywhere | ⚠️ OpenShift only |
| **Learning** | Standard K8s | OpenShift-specific |

**For learning**: Use standard K8s resources first, then explore OpenShift features.

## Next Steps

1. Run your first pipeline
2. Experiment with Routes
3. Try ImageStreams
4. Explore OpenShift BuildConfigs
5. Set up webhooks for automatic builds

## Additional Resources

- [OpenShift Jenkins Documentation](https://docs.openshift.com/container-platform/latest/cicd/jenkins/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [OpenShift Routes](https://docs.openshift.com/container-platform/latest/networking/routes/)

Happy Learning! 🚀

