# Alternative Jenkinsfile Using kubectl

If `oc` CLI is not available in your Jenkins pod, you can use `kubectl` instead. `kubectl` works with OpenShift!

## Option 1: Use kubectl (Simpler)

Most Jenkins pods have `kubectl` available. Here's a simplified Jenkinsfile that uses `kubectl`:

```groovy
stage('Deploy to OpenShift') {
    steps {
        script {
            echo "Deploying to OpenShift using kubectl..."
            
            // Create namespace
            sh """
                kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            """
            
            // Update and apply manifests
            dir('CICD/k8s-manifests') {
                sh """
                    # Update image
                    perl -i -pe "s|image:.*${IMAGE_NAME}.*|image: ${FULL_IMAGE_NAME}|g" deployment.yaml
                    
                    # Apply manifests
                    kubectl apply -f namespace.yaml
                    kubectl apply -f deployment.yaml
                    kubectl apply -f service.yaml
                    kubectl apply -f ingress.yaml
                """
            }
            
            // Wait for rollout
            sh """
                kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=5m
            """
        }
    }
}
```

## Option 2: Install oc in Jenkinsfile

The main Jenkinsfile now includes a stage to install `oc` if it's not available. This should work automatically.

## Option 3: Use OpenShift Jenkins Plugin

Instead of using CLI commands, use the OpenShift Jenkins plugin:

1. Install plugin: **OpenShift Client Plugin**
2. Use plugin steps in Jenkinsfile:

```groovy
stage('Deploy to OpenShift') {
    steps {
        script {
            openshift.withCluster() {
                openshift.withProject("${NAMESPACE}") {
                    openshift.apply(readFile("CICD/k8s-manifests/deployment.yaml"))
                }
            }
        }
    }
}
```

## Verifying kubectl Works

```bash
# Check if kubectl is available
oc exec -n jenkins jenkins-0 -- kubectl version --client

# Test kubectl can connect
oc exec -n jenkins jenkins-0 -- kubectl get nodes
```

If `kubectl` works, you can use it instead of `oc` - it's fully compatible with OpenShift!

