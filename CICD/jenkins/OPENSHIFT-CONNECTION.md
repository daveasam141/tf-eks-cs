# How Jenkins Connects to OpenShift Cluster

## The Short Answer

**Jenkins automatically connects to the OpenShift cluster it's running on** using the service account token. No manual configuration needed!

## How It Works

### When Jenkins Runs on OpenShift

When Jenkins is installed on OpenShift (via Software Catalog or Helm), it runs as a pod with a **Service Account**. This service account has:

1. **Automatic Authentication**: Jenkins uses the service account's token to authenticate with OpenShift
2. **Cluster Access**: Since Jenkins is running IN the cluster, it has access to the cluster's API server
3. **No Manual Config**: The `oc` CLI automatically uses the service account token

### Service Account Token

OpenShift automatically mounts the service account token at:
```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

The `oc` CLI automatically uses this token when running inside a pod.

## Verifying the Connection

### From Jenkins Pod

```bash
# Get Jenkins pod name
oc get pods -n jenkins

# Check if oc CLI is available
oc exec -n jenkins <jenkins-pod-name> -- oc version --client

# If oc is not available, check kubectl
oc exec -n jenkins <jenkins-pod-name> -- kubectl version --client

# Test connection (using oc or kubectl)
oc exec -n jenkins <jenkins-pod-name> -- kubectl get nodes
oc exec -n jenkins <jenkins-pod-name> -- kubectl get projects
```

**Note**: If `oc` is not installed, `kubectl` works perfectly with OpenShift! The Jenkinsfile handles both.

**Expected output:**
```
Client Version: version.Info{...}
Server Version: version.Info{...}
```

### From Jenkins Pipeline

The Jenkinsfile automatically:
1. Checks if `oc` CLI is available
2. Falls back to `kubectl` if `oc` is not available
3. `kubectl` works perfectly with OpenShift!

Both `oc` and `kubectl` use the same service account token for authentication.

## RBAC Permissions

### Default Permissions

Jenkins service account needs permissions to:
- Create/update deployments
- Create/update services
- Create/update routes
- Create namespaces/projects

### Granting Permissions

If Jenkins can't deploy, grant permissions:

```bash
# Find Jenkins service account
JENKINS_NS="jenkins"
JENKINS_SA="jenkins"  # Usually the service account name

# Grant edit role to Jenkins service account in target namespace
oc policy add-role-to-user edit system:serviceaccount:${JENKINS_NS}:${JENKINS_SA} -n cicd-app

# Or grant cluster-admin (for learning, not production!)
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:${JENKINS_NS}:${JENKINS_SA}
```

### Check Current Permissions

```bash
# Check what permissions Jenkins service account has
oc describe rolebinding -n cicd-app | grep jenkins
oc get rolebinding -n cicd-app
```

## How `oc` CLI Works in Jenkins Pod

### Automatic Configuration

When `oc` runs inside an OpenShift pod:

1. **Auto-detects**: It automatically detects it's running in a pod
2. **Uses Service Account Token**: Reads token from `/var/run/secrets/kubernetes.io/serviceaccount/token`
3. **Uses Cluster Info**: Reads cluster info from `/var/run/secrets/kubernetes.io/serviceaccount/namespace` and API server
4. **No Manual Login**: No need to run `oc login`

### Manual Configuration (If Needed)

If for some reason auto-detection doesn't work:

```bash
# Get service account token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Get API server URL
APISERVER=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
APISERVER="https://kubernetes.default.svc"  # Internal API server

# Login manually
oc login --token=$TOKEN --server=$APISERVER
```

## Deploying to Different Clusters

### If Jenkins is NOT on the Target Cluster

If Jenkins is running elsewhere and needs to deploy to OpenShift:

1. **Get OpenShift Token**:
   ```bash
   oc whoami -t  # Get your token
   ```

2. **Add as Jenkins Credential**:
   - Jenkins → Credentials → Add
   - Kind: Secret text
   - Secret: Your OpenShift token
   - ID: `openshift-token`

3. **Update Jenkinsfile**:
   ```groovy
   withCredentials([string(credentialsId: 'openshift-token', variable: 'OC_TOKEN')]) {
       sh """
           oc login --token=${OC_TOKEN} --server=https://api.your-cluster.com:6443
           oc project ${NAMESPACE}
           # ... deploy ...
       """
   }
   ```

### If Jenkins is on the Same Cluster (Your Case)

**No configuration needed!** Jenkins automatically uses the service account token.

## Troubleshooting Connection Issues

### Issue: "oc command not found"

**Solution**: Use `kubectl` instead! It works with OpenShift:

```bash
# Check if kubectl is available
oc exec -n jenkins <jenkins-pod> -- kubectl version --client

# If kubectl works, use it in Jenkinsfile
# The updated Jenkinsfile automatically uses kubectl if oc is not available
```

### Issue: "Unable to connect to the server"

**Check:**
```bash
# Verify Jenkins pod can reach API server
oc exec -n jenkins <jenkins-pod> -- curl -k https://kubernetes.default.svc

# Check service account token exists
oc exec -n jenkins <jenkins-pod> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Test with kubectl
oc exec -n jenkins <jenkins-pod> -- kubectl get nodes
```

### Issue: "Forbidden" or "Access Denied"

**Solution**: Grant permissions (see RBAC Permissions section above)

### Issue: "No route to host"

**Check:**
- Jenkins pod network connectivity
- Service account exists: `oc get sa -n jenkins`
- Pod is running: `oc get pods -n jenkins`

## Summary

**For your setup (Jenkins on OpenShift):**
- ✅ Jenkins automatically connects to the cluster it's running on
- ✅ Uses service account token (no manual login)
- ✅ `oc` CLI works automatically in Jenkins pods
- ✅ Just need to grant RBAC permissions for deployments

**No manual cluster configuration needed!** The Jenkinsfile will work out of the box once permissions are set.

