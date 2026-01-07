# Installing CLI Tools in Jenkins Pod

## The Problem

When you check for `oc` or `kubectl` in the Jenkins pod, they're not available:
```bash
oc exec -n jenkins jenkins-0 -- oc version --client
# Error: executable file `oc` not found
```

## Solutions

### Option 1: Install OpenShift Client Plugin (Recommended)

**Best approach**: Use the OpenShift Client Plugin which doesn't require CLI tools!

1. **Install Plugin**:
   - Jenkins UI → **Manage Jenkins** → **Manage Plugins**
   - Search for: **OpenShift Client Plugin**
   - Install and restart Jenkins

2. **Use Plugin in Pipeline**:
   - Use `Jenkinsfile.openshift-plugin` (already created)
   - Or copy the deploy stage from that file

**Advantages**:
- ✅ No CLI installation needed
- ✅ Works out of the box
- ✅ Native OpenShift integration
- ✅ Better error handling

### Option 2: Install CLI Tools During Pipeline (Current Approach)

The main `Jenkinsfile` installs `oc` CLI during pipeline execution.

**How it works**:
1. Pipeline runs "Install OpenShift CLI" stage
2. Downloads `oc` CLI to `/tmp/jenkins-bin/`
3. Uses it for deployment
4. Installation happens **each time** pipeline runs

**To see it work**:
1. Start the pipeline
2. Watch the "Install OpenShift CLI" stage
3. You'll see download and installation logs

### Option 3: Install CLI Tools Permanently in Jenkins Pod

Install tools directly in the Jenkins container so they're always available:

#### Method A: Exec into Pod and Install

```bash
# Get Jenkins pod
JENKINS_POD=$(oc get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')

# Exec into pod
oc exec -it -n jenkins $JENKINS_POD -- bash

# Inside pod, install oc
cd /tmp
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    OC_ARCH="amd64"
else
    OC_ARCH="arm64"
fi

curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OC_ARCH}.tar.gz -o oc.tar.gz
tar -xz -f oc.tar.gz oc
mv oc /usr/local/bin/
chmod +x /usr/local/bin/oc
rm oc.tar.gz

# Verify
oc version --client
```

**Note**: This will be lost if the pod restarts!

#### Method B: Create Custom Jenkins Image

Create a Dockerfile that extends Jenkins image with CLI tools:

```dockerfile
FROM jenkins/jenkins:lts

USER root

# Install oc CLI
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then OC_ARCH="amd64"; else OC_ARCH="arm64"; fi && \
    curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OC_ARCH}.tar.gz | \
    tar -xz -C /usr/local/bin/ oc && \
    chmod +x /usr/local/bin/oc

USER jenkins
```

Then build and use this image for Jenkins.

#### Method C: Use Init Container (If Using Helm/Operator)

If you installed Jenkins via Helm, you can add an init container:

```yaml
# In your Helm values or Deployment
initContainers:
  - name: install-oc
    image: curlimages/curl:latest
    command:
      - sh
      - -c
      - |
        curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-amd64.tar.gz | \
        tar -xz -C /shared oc && \
        chmod +x /shared/oc
    volumeMounts:
      - name: shared-bin
        mountPath: /shared
containers:
  - name: jenkins
    volumeMounts:
      - name: shared-bin
        mountPath: /usr/local/bin
volumes:
  - name: shared-bin
    emptyDir: {}
```

## Quick Test: Which Method Works?

### Test 1: Check if OpenShift Plugin is Available

```bash
# In Jenkins UI, check if plugin is installed
# Manage Jenkins → Manage Plugins → Installed
# Look for "OpenShift Client Plugin"
```

If installed → Use `Jenkinsfile.openshift-plugin`

### Test 2: Try Pipeline Installation

1. Start pipeline with main `Jenkinsfile`
2. Check "Install OpenShift CLI" stage logs
3. If successful → Tools installed for that run

### Test 3: Install Permanently

Use Method A above to install in running pod (temporary) or Method B/C for permanent.

## Recommendation

**For Learning**: Use Option 1 (OpenShift Client Plugin) - it's the cleanest approach.

**For Production**: Use Option 3 Method B (Custom Image) - most reliable.

**For Quick Testing**: Use Option 2 (Pipeline Installation) - works immediately.

## Troubleshooting

### Installation Fails During Pipeline

**Check**:
- Network connectivity from Jenkins pod
- Firewall rules
- Disk space: `oc exec -n jenkins jenkins-0 -- df -h`

**Solution**: Use OpenShift Client Plugin instead

### Tools Installed But Not Found

**Check PATH**:
```bash
oc exec -n jenkins jenkins-0 -- echo $PATH
oc exec -n jenkins jenkins-0 -- which oc
```

**Solution**: Ensure `/usr/local/bin` is in PATH, or use full path in Jenkinsfile

### Permission Denied

**Check**:
```bash
oc exec -n jenkins jenkins-0 -- ls -la /usr/local/bin/oc
```

**Solution**: Ensure executable permissions: `chmod +x /usr/local/bin/oc`

