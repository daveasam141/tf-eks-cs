# Installing Core Services on EKS

This guide provides an overview and installation order for core services: cert-manager, Istio, and External DNS.

## Installation Order

Install services in this order to avoid dependency issues:

1. **cert-manager** - Certificate management (no dependencies)
2. **Istio** - Service mesh (no dependencies, but works with cert-manager)
3. **External DNS** - DNS management (requires IAM role/IRSA)

## Quick Start

### Prerequisites Check

```bash
# Verify cluster access
kubectl cluster-info

# Verify helm is installed
helm version

# Get IAM role ARN for External DNS (if using Terraform)
terraform output -raw external_dns_iam_role_arn
```

### Installation Commands

```bash
# 1. Install cert-manager
# See: INSTALL-CERT-MANAGER.md
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.3 \
  --set installCRDs=true \
  --wait

# 2. Install Istio
# See: INSTALL-ISTIO.md
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base --namespace istio-system --version 1.20.0 --wait
helm install istiod istio/istiod --namespace istio-system --version 1.20.0 --wait
kubectl create namespace istio-ingress
helm install istio-ingress istio/gateway \
  --namespace istio-ingress \
  --version 1.20.0 \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait

# 3. Install External DNS
# See: INSTALL-EXTERNAL-DNS.md
export DOMAIN_NAME="example.com"
export IAM_ROLE_ARN="arn:aws:iam::123456789012:role/lab-eks-cluster-external-dns"
export AWS_REGION="us-east-1"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
kubectl create namespace external-dns
helm install external-dns bitnami/external-dns \
  --namespace external-dns \
  --version 6.14.4 \
  --set provider=aws \
  --set aws.region=$AWS_REGION \
  --set domainFilters[0]=$DOMAIN_NAME \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$IAM_ROLE_ARN \
  --wait
```

## Detailed Guides

- **[cert-manager Installation](./INSTALL-CERT-MANAGER.md)** - Step-by-step cert-manager setup
- **[Istio Installation](./INSTALL-ISTIO.md)** - Complete Istio service mesh setup
- **[External DNS Installation](./INSTALL-EXTERNAL-DNS.md)** - Route53 DNS automation

## Verification

After installation, verify all services:

```bash
# Check cert-manager
kubectl get pods -n cert-manager
kubectl get clusterissuer

# Check Istio
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
kubectl get svc -n istio-ingress

# Check External DNS
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20
```

## Next Steps

### 1. Configure cert-manager ClusterIssuer

Create a Let's Encrypt ClusterIssuer (see [INSTALL-CERT-MANAGER.md](./INSTALL-CERT-MANAGER.md))

### 2. Enable Istio Sidecar Injection

```bash
# Enable for default namespace
kubectl label namespace default istio-injection=enabled

# Or enable for specific namespaces
kubectl label namespace my-app istio-injection=enabled
```

### 3. Create Istio Gateway

Create a Gateway and VirtualService to expose your applications (see [INSTALL-ISTIO.md](./INSTALL-ISTIO.md))

### 4. Test Integration

Deploy a test application with:
- External DNS annotation for DNS record
- cert-manager annotation for TLS certificate
- Istio Gateway for traffic management

## Example: Complete Setup

Here's an example of deploying an app with all three services:

```yaml
# 1. Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: app
        image: nginx:latest
---
# 2. Service
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
---
# 3. Gateway
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-app-gateway
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
      credentialName: my-app-tls
    hosts:
    - app.example.com
---
# 4. VirtualService
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-app-vs
spec:
  hosts:
  - app.example.com
  gateways:
  - my-app-gateway
  http:
  - route:
    - destination:
        host: my-app
        port:
          number: 80
---
# 5. Certificate (cert-manager)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.example.com
```

This setup will:
1. **External DNS** creates `app.example.com` → LoadBalancer IP
2. **cert-manager** requests and obtains TLS certificate
3. **Istio Gateway** serves traffic with TLS
4. **Istio VirtualService** routes to your app

## Troubleshooting

See individual service guides for detailed troubleshooting:
- [cert-manager Troubleshooting](./INSTALL-CERT-MANAGER.md#troubleshooting)
- [Istio Troubleshooting](./INSTALL-ISTIO.md#troubleshooting)
- [External DNS Troubleshooting](./INSTALL-EXTERNAL-DNS.md#troubleshooting)

## Uninstalling Services

To remove all services:

```bash
# Uninstall in reverse order
helm uninstall external-dns -n external-dns
helm uninstall istio-ingress -n istio-ingress
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
helm uninstall cert-manager -n cert-manager

# Delete namespaces
kubectl delete namespace external-dns istio-ingress istio-system cert-manager
```


