# Installing Istio Service Mesh

This guide walks you through installing Istio service mesh on your EKS cluster using Helm.

## Prerequisites

- EKS cluster is running and accessible
- `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- `helm` installed (version 3.x)
- Sufficient cluster resources (Istio requires ~1 CPU and 1.5GB RAM)

## Installation Profiles

Istio offers different installation profiles:

- **default**: Full Istio with all components (recommended for production)
- **demo**: Full Istio with additional features for demos
- **minimal**: Only Istiod (control plane), no gateways
- **remote**: For multi-cluster setups
- **empty**: Base installation only

**For learning/lab**: Use `default` or `demo`  
**For production**: Use `default`  
**For minimal setup**: Use `minimal`

## Installation Steps

### Step 1: Add Istio Helm Repository

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

### Step 2: Install Istio Base (CRDs)

```bash
# Create istio-system namespace
kubectl create namespace istio-system

# Install Istio base (CRDs)
helm install istio-base istio/base \
  --namespace istio-system \
  --version 1.20.0 \
  --wait
```

### Step 3: Install Istiod (Control Plane)

```bash
helm install istiod istio/istiod \
  --namespace istio-system \
  --version 1.20.0 \
  --set global.istioNamespace=istio-system \
  --wait \
  --timeout 10m
```

### Step 4: Install Istio Ingress Gateway (Optional but Recommended)

```bash
# Create istio-ingress namespace
kubectl create namespace istio-ingress

# Install ingress gateway
helm install istio-ingress istio/gateway \
  --namespace istio-ingress \
  --version 1.20.0 \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait \
  --timeout 10m
```

### Step 5: Install Istio Egress Gateway (Optional)

Only needed if you want egress gateway features:

```bash
# Create istio-egress namespace
kubectl create namespace istio-egress

# Install egress gateway
helm install istio-egress istio/gateway \
  --namespace istio-egress \
  --version 1.20.0 \
  --wait \
  --timeout 10m
```

## Verify Installation

### Check Pods

```bash
# Check Istiod (control plane)
kubectl get pods -n istio-system

# Check ingress gateway
kubectl get pods -n istio-ingress

# Check egress gateway (if installed)
kubectl get pods -n istio-egress
```

Expected output:
```
# istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istiod-xxx                              1/1     Running   0          5m

# istio-ingress
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-xxx                1/1     Running   0          3m
```

### Verify Installation with istioctl

If you have `istioctl` installed:

```bash
# Download istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl verify-install

# Check proxy status
istioctl proxy-status
```

### Get Ingress Gateway LoadBalancer Address

```bash
# Wait for LoadBalancer (takes 1-2 minutes)
kubectl get svc istio-ingressgateway -n istio-ingress

# Get the external address
kubectl get svc istio-ingressgateway -n istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Enabling Sidecar Injection

Istio uses sidecar injection to add Envoy proxies to your pods. Two methods:

### Method 1: Automatic Injection (Namespace Level)

Label a namespace for automatic injection:

```bash
# Enable for a namespace
kubectl label namespace default istio-injection=enabled

# Verify
kubectl get namespace -L istio-injection
```

All new pods in this namespace will automatically get Istio sidecars.

### Method 2: Manual Injection (Pod Level)

Add annotation to pod/deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: my-app
        image: nginx:latest
```

## Creating a Gateway and VirtualService

### Example: Expose an Application via Istio Gateway

Create `istio-gateway.yaml`:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-app-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway  # Use Istio ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - app.example.com
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-app-vs
  namespace: default
spec:
  hosts:
  - app.example.com
  gateways:
  - my-app-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: my-app
        port:
          number: 80
```

Apply:
```bash
kubectl apply -f istio-gateway.yaml
```

## Using Istio with cert-manager

To use TLS with Istio Gateway:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-app-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: app-tls  # Secret created by cert-manager
    hosts:
    - app.example.com
```

## Common Operations

### Check Sidecar Injection

```bash
# Check if pod has sidecar
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'

# Should show: <app-container> istio-proxy
```

### View Istio Configuration

```bash
# List all Istio resources
kubectl get virtualservices
kubectl get gateways
kubectl get destinationrules
kubectl get serviceentries
```

### Access Istio Dashboard (Kiali)

Install Kiali for Istio observability:

```bash
helm repo add kiali https://kiali.org/helm-charts
helm install kiali-operator kiali/kiali-operator \
  --namespace kiali-operator \
  --create-namespace \
  --set cr.create=true \
  --set cr.namespace=istio-system
```

Access Kiali:
```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open http://localhost:20001
```

## Troubleshooting

### Check Istio Pods

```bash
# Check all Istio pods
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Check logs
kubectl logs -n istio-system -l app=istiod
kubectl logs -n istio-ingress -l app=istio-ingressgateway
```

### Verify Sidecar Injection

```bash
# Check if namespace has injection enabled
kubectl get namespace default -o jsonpath='{.metadata.labels.istio-injection}'

# Check pod has sidecar
kubectl describe pod <pod-name> | grep -A 5 Containers
```

### Common Issues

**Issue: Sidecars not injecting**
- Verify namespace label: `kubectl get namespace -L istio-injection`
- Check pod annotation: `kubectl get pod <pod-name> -o yaml | grep sidecar`
- Restart pods after enabling injection

**Issue: Gateway not accessible**
- Check LoadBalancer status: `kubectl get svc -n istio-ingress`
- Verify Gateway and VirtualService are created
- Check DNS points to LoadBalancer

**Issue: 503 errors**
- Check destination service exists: `kubectl get svc`
- Verify VirtualService routes correctly
- Check sidecar is injected: `kubectl get pod -o jsonpath='{.spec.containers[*].name}'`

## Upgrading Istio

```bash
# Check current version
helm list -n istio-system

# Upgrade Istiod
helm upgrade istiod istio/istiod \
  --namespace istio-system \
  --version 1.20.0 \
  --reuse-values

# Upgrade gateways
helm upgrade istio-ingress istio/gateway \
  --namespace istio-ingress \
  --version 1.20.0 \
  --reuse-values
```

## Uninstalling Istio

```bash
# Uninstall gateways
helm uninstall istio-ingress -n istio-ingress
helm uninstall istio-egress -n istio-egress

# Uninstall Istiod
helm uninstall istiod -n istio-system

# Uninstall base
helm uninstall istio-base -n istio-system

# Delete CRDs (removes all Istio resources)
kubectl delete crd -l app=istio

# Delete namespaces
kubectl delete namespace istio-system istio-ingress istio-egress
```

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Installation Guide](https://istio.io/latest/docs/setup/install/)
- [Istio Gateway Configuration](https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/)


