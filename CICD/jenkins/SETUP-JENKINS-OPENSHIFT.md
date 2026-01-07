# Setting Up Jenkins on OpenShift

Step-by-step guide for configuring Jenkins installed via OpenShift Software Catalog.

## Finding Your Jenkins Installation

##Installing jenkins on openshoft with helm
oc create project jenkins
oc adm policy add-scc-to-user anyuid -z jenkins -n jenkins(This allows jenkins to run as the user it wants to in the pod 1000 root, openshift security constraints won't allow it to do that by default)
helm repo add jenkins https://charts.jenkins.io\nhelm repo update\nhelm install jenkins jenkins/jenkins -n jenkins

### Step 1: Locate Jenkins in OpenShift

```bash
# List all projects/namespaces
oc get projects | grep jenkins

# Or check in OpenShift UI:
# Projects → Look for jenkins or similar
```

### Step 2: Get Jenkins Access Information

```bash
# Set your Jenkins namespace (replace with actual namespace)
JENKINS_NS="jenkins"  # or whatever namespace Jenkins is in

# Get Jenkins route (URL)
oc get route -n $JENKINS_NS | grep jenkins

# Get Jenkins admin username
oc get secret jenkins -n $JENKINS_NS -o jsonpath='{.data.jenkins-admin-user}' | base64 -d
echo

# Get Jenkins admin password
oc get secret jenkins -n $JENKINS_NS -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
echo
```

### Step 3: Access Jenkins UI

1. Get the route URL from Step 2
2. Open in browser
3. Login with admin credentials

## Configuring Jenkins for Your Pipeline

### Step 1: Install Required Plugins

Jenkins installed via OpenShift Software Catalog usually comes with plugins pre-installed, but verify:

1. Jenkins UI → **Manage Jenkins** → **Manage Plugins**
2. Check these plugins are installed:
   - ✅ **Pipeline** (usually pre-installed)
   - ✅ **Git** (usually pre-installed)
   - ✅ **Docker Pipeline** (install if missing)
   - ✅ **OpenShift Client Plugin** ⭐ **RECOMMENDED** (install if missing - doesn't require CLI tools!)
   - ✅ **Kubernetes CLI** (optional - install if missing)

3. If any are missing:
   - Go to **Available** tab
   - Search and install
   - **Restart Jenkins if prompted**

**Important**: If you install **OpenShift Client Plugin**, you can use `Jenkinsfile.openshift-plugin` which doesn't require `oc` or `kubectl` CLI tools!

See [INSTALL-CLI-TOOLS.md](./INSTALL-CLI-TOOLS.md) for details on CLI installation options.

### Step 2: Verify OpenShift Connection

Jenkins automatically connects to the OpenShift cluster it's running on using the service account token. Verify:

```bash
# Get Jenkins pod name
JENKINS_POD=$(oc get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')

# Verify oc CLI is available and can connect
oc exec -n jenkins $JENKINS_POD -- oc whoami
oc exec -n jenkins $JENKINS_POD -- oc cluster-info
```

**Expected output:**
```
system:serviceaccount:jenkins:jenkins
Kubernetes control plane is running at https://...
```

**If this works, Jenkins is already connected!** No additional configuration needed.

### Step 3: Grant Jenkins Permissions

Jenkins needs permissions to deploy to your application namespace:

```bash
# Grant edit role to Jenkins service account
JENKINS_NS="jenkins"
TARGET_NS="cicd-app"

oc policy add-role-to-user edit system:serviceaccount:${JENKINS_NS}:jenkins -n ${TARGET_NS}

# Or if Jenkins service account has different name, find it:
oc get sa -n ${JENKINS_NS}
# Then use the actual service account name
```

**Note**: For learning, you can grant cluster-admin (not recommended for production):

```bash
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:${JENKINS_NS}:jenkins
```

See [OPENSHIFT-CONNECTION.md](./OPENSHIFT-CONNECTION.md) for detailed explanation.

### Step 4: Add Docker Hub Credentials

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

### Step 5: Add GitHub Credentials (If Private Repo)

If your repository is private:

1. **Add Credentials**
2. **Kind**: Secret text
3. **Secret**: GitHub Personal Access Token
4. **ID**: `github-token`
5. Click **Create**

## Creating the Pipeline Job

### Method 1: From Jenkinsfile in Git (Recommended)

1. Jenkins UI → **New Item**
2. Enter name: `cicd-app-pipeline`
3. Select **Pipeline**
4. Click **OK**

**Configure:**
- **Description**: CI/CD pipeline for Python app
- **Pipeline** section:
  - **Definition**: Pipeline script from SCM
  - **SCM**: Git
  - **Repository URL**: Your GitHub repo URL
  - **Credentials**: Select GitHub token (if private repo)
  - **Branches to build**: `*/main` (or your branch)
  - **Script Path**: `CICD/jenkins/Jenkinsfile`
- Click **Save**

### Method 2: Manual Pipeline Script

1. Create pipeline job as above
2. **Definition**: Pipeline script
3. Copy contents of `jenkins/Jenkinsfile` into script box
4. Click **Save**

## Testing the Pipeline

### First Run

1. Go to your pipeline job
2. Click **Build Now**
3. Watch the console output:
   - Click on the build number
   - Click **Console Output**
   - Watch each stage execute

### Verify Each Stage

**Checkout:**
- Should show "Checking out code..."

**Test:**
- Should show pytest output
- Tests should pass

**Build:**
- Should show Docker build output
- Image should build successfully

**Security Scan:**
- Should show Trivy scan results

**Push:**
- Should show "Pushing to Docker Hub..."
- Check Docker Hub to verify image was pushed

**Deploy:**
- Should show "Deploying to OpenShift..."
- Should create/update resources
- Should show rollout status

## Verifying Deployment

```bash
# Check if namespace was created
oc get project cicd-app

# Check deployment
oc get deployment -n cicd-app

# Check pods
oc get pods -n cicd-app

# Check service
oc get svc -n cicd-app

# Check route (if using Routes)
oc get route -n cicd-app

# Get application URL
oc get route cicd-app -n cicd-app -o jsonpath='{.spec.host}'
echo

# Test the application
curl http://$(oc get route cicd-app -n cicd-app -o jsonpath='{.spec.host}')/
```

## Setting Up Webhooks (Optional)

To trigger builds automatically on Git push:

### Step 1: Get Jenkins Webhook URL

```bash
# Get Jenkins route
JENKINS_URL=$(oc get route -n $JENKINS_NS -o jsonpath='{.items[0].spec.host}')

# Webhook URL format:
echo "https://${JENKINS_URL}/github-webhook/"
```

### Step 2: Configure GitHub Webhook

1. GitHub repo → **Settings** → **Webhooks**
2. Click **Add webhook**
3. **Payload URL**: `https://<jenkins-url>/github-webhook/`
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
oc get pods -n $JENKINS_NS

# Check Jenkins route
oc get route -n $JENKINS_NS

# Check Jenkins service
oc get svc -n $JENKINS_NS

# View Jenkins pod logs
oc logs -n $JENKINS_NS -l app=jenkins --tail=50
```

### Pipeline Failing at Docker Build

**Issue**: Docker daemon not available in Jenkins pod

**Solution**: OpenShift Jenkins usually has Docker-in-Docker or Buildah available. Check:

```bash
# Check if docker command is available
oc exec -n $JENKINS_NS <jenkins-pod> -- docker --version

# Or check for buildah
oc exec -n $JENKINS_NS <jenkins-pod> -- buildah --version
```

If neither is available, you may need to use OpenShift BuildConfig instead of Docker build.

### Pipeline Failing at OpenShift Deploy

**Issue**: Permission denied

**Solution**: Grant permissions to Jenkins service account:

```bash
# Find Jenkins service account
oc get sa -n $JENKINS_NS | grep jenkins

# Grant edit role
oc policy add-role-to-user edit system:serviceaccount:$JENKINS_NS:jenkins -n cicd-app
```

### Image Pull Errors

**Issue**: Can't pull image from Docker Hub

**Solution**: 
1. Verify Docker Hub credentials in Jenkins
2. Check image exists: `docker pull YOUR_USERNAME/cicd-learning-app:latest`
3. If using private image, create image pull secret in OpenShift

## Using OpenShift BuildConfig (Alternative)

Instead of building in Jenkins, you can use OpenShift's native BuildConfig:

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: cicd-app-build
spec:
  source:
    type: Git
    git:
      uri: https://github.com/YOUR_USERNAME/YOUR_REPO.git
      ref: main
    contextDir: CICD/app
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  output:
    to:
      kind: ImageStreamTag
      name: cicd-app:latest
  triggers:
  - type: ConfigChange
  - type: GitHub
    github:
      secret: github-webhook-secret
```

This builds directly in OpenShift, but for learning Jenkins, building in Jenkins is better.

## Next Steps

1. Run your first successful pipeline
2. Set up webhooks for automatic builds
3. Experiment with different pipeline stages
4. Try using Routes instead of Ingress
5. Explore OpenShift ImageStreams

## Additional Resources

- [OpenShift Jenkins Guide](https://docs.openshift.com/container-platform/latest/cicd/jenkins/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [OpenShift CLI Reference](https://docs.openshift.com/container-platform/latest/cli_reference/)

