# Installing cert-manager

This guide walks you through installing cert-manager on your EKS cluster for automatic TLS certificate management.

## Prerequisites

- EKS cluster is running and accessible
- `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- `helm` installed (version 3.x)

## Installation Steps

### Step 1: Add cert-manager Helm Repository

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### Step 2: Install cert-manager

```bash
# Create namespace
kubectl create namespace cert-manager

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.3 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --wait \
  --timeout 5m
```

**What this does:**
- `installCRDs=true`: Installs Custom Resource Definitions (Certificate, ClusterIssuer, etc.)
- `--wait`: Waits for deployment to be ready
- `--timeout 5m`: Maximum wait time

### Step 3: Verify Installation

```bash
# Check pods are running
kubectl get pods -n cert-manager

# Verify CRDs are installed
kubectl get crds | grep cert-manager

# Should see:
# - certificates.cert-manager.io
# - certificaterequests.cert-manager.io
# - clusterissuers.cert-manager.io
# - issuers.cert-manager.io
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-xxx                          1/1     Running   0          2m
cert-manager-cainjector-xxx               1/1     Running   0          2m
cert-manager-webhook-xxx                  1/1     Running   0          2m
```

## Next Steps: Configure ClusterIssuer

### Create Let's Encrypt ClusterIssuer

Create a file `cert-manager-clusterissuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt production server
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address for account registration
    email: davidasam141@gmail.com  # CHANGE THIS
    # Store account key in a Secret
    privateKeySecretRef:
      name: letsencrypt-prod
    # Use HTTP-01 challenge
    solvers:
    - http01:
        ingress:
          class: nginx
```

**For staging (testing):**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply the ClusterIssuer:

```bash
kubectl apply -f cert-manager-clusterissuer.yaml
```

Verify:
```bash
kubectl get clusterissuer
```

## Using cert-manager with Ingress

### Request Certificate via Ingress Annotation

Add these annotations to your Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    # Request certificate from cert-manager
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # External DNS annotation (if using External DNS)
    external-dns.alpha.kubernetes.io/hostname: app.example.com
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls  # cert-manager will create this secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

### Request Certificate via Certificate Resource

Create a Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-certificate
  namespace: default
spec:
  secretName: app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.example.com
  - www.example.com
```

Apply:
```bash
kubectl apply -f certificate.yaml
```

Check certificate status:
```bash
kubectl get certificate
kubectl describe certificate app-certificate
```

## Troubleshooting

### Check cert-manager logs

```bash
# cert-manager controller logs
kubectl logs -n cert-manager -l app=cert-manager

# cert-manager webhook logs
kubectl logs -n cert-manager -l app=webhook

# cert-manager cainjector logs
kubectl logs -n cert-manager -l app=cainjector
```

### Check Certificate status

```bash
# List certificates
kubectl get certificate -A

# Describe certificate for details
kubectl describe certificate <certificate-name> -n <namespace>

# Check CertificateRequest
kubectl get certificaterequest -A
kubectl describe certificaterequest <request-name> -n <namespace>
```

### Common Issues

**Issue: Certificate stuck in "Pending"**
- Check ClusterIssuer is created: `kubectl get clusterissuer`
- Verify Ingress class matches: `kubectl get ingressclass`
- Check cert-manager logs for errors

**Issue: "Failed to verify ACME account"**
- Check email address is correct
- Verify DNS is pointing to your LoadBalancer
- For staging, use `letsencrypt-staging` issuer first

**Issue: "Challenge failed"**
- Ensure your domain points to the LoadBalancer IP
- Check Ingress is accessible: `curl -I http://your-domain.com/.well-known/acme-challenge/test`

## Upgrading cert-manager

```bash
# Check current version
helm list -n cert-manager

# Upgrade to latest version
helm repo update
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --reuse-values
```

## Uninstalling cert-manager

```bash
# Uninstall Helm release
helm uninstall cert-manager -n cert-manager

# Delete CRDs (optional, removes all certificates)
kubectl delete crd certificates.cert-manager.io
kubectl delete crd certificaterequests.cert-manager.io
kubectl delete crd clusterissuers.cert-manager.io
kubectl delete crd issuers.cert-manager.io

# Delete namespace
kubectl delete namespace cert-manager
```

## Additional Resources

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [ACME Challenge Types](https://cert-manager.io/docs/configuration/acme/)


