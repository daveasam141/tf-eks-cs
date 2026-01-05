# Installing External DNS

This guide walks you through installing External DNS on your EKS cluster for automatic DNS record management in Route53.

## Prerequisites

- EKS cluster is running and accessible
- `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- `helm` installed (version 3.x)
- Route53 hosted zone for your domain
- IAM role with Route53 permissions (IRSA) - see Terraform configuration

## Prerequisites Setup

### 1. Get IAM Role ARN

If External DNS IAM role was created via Terraform:

```bash
# Get the IAM role ARN from Terraform output
terraform output -raw external_dns_iam_role_arn

# Or find it manually
aws iam list-roles --query 'Roles[?contains(RoleName, `external-dns`)].Arn' --output text
```

### 2. Verify Route53 Hosted Zone

```bash
# List your hosted zones
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table

# Get hosted zone ID for your domain
DOMAIN="example.com"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN" \
  --query 'HostedZones[0].Id' \
  --output text | sed 's|/hostedzone/||')

echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

## Installation Steps

### Step 1: Add External DNS Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Step 2: Set Configuration Variables

```bash
# Set your domain
export DOMAIN_NAME="example.com"  # CHANGE THIS

# Set hosted zone ID (optional, will auto-detect if not set)
export HOSTED_ZONE_ID="Z1234567890ABC"  # Optional

# Set IAM role ARN (from Terraform or manually created)
export IAM_ROLE_ARN="arn:aws:iam::123456789012:role/lab-eks-cluster-external-dns"  # CHANGE THIS

# Set AWS region
export AWS_REGION="us-east-1"  # CHANGE THIS
```

### Step 3: Create Namespace

```bash
kubectl create namespace external-dns
```

### Step 4: Install External DNS

```bash
helm install external-dns bitnami/external-dns \
  --namespace external-dns \
  --version 6.14.4 \
  --set provider=aws \
  --set aws.region=$AWS_REGION \
  --set aws.zoneType=public \
  --set domainFilters[0]=$DOMAIN_NAME \
  --set txtOwnerId=$HOSTED_ZONE_ID \
  --set policy=sync \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$IAM_ROLE_ARN \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi \
  --wait \
  --timeout 5m
```

### Step 5: Verify Installation

```bash
# Check pod is running
kubectl get pods -n external-dns

# Check logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# Verify service account has IAM role
kubectl get sa external-dns -n external-dns -o yaml
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
external-dns-xxx               1/1     Running   0          2m
```

## Configuration Options

### Domain Filters

To manage multiple domains:

```bash
--set domainFilters[0]=example.com \
--set domainFilters[1]=subdomain.example.com
```

### TXT Owner ID

The `txtOwnerId` prevents conflicts when multiple External DNS instances manage the same zone. Use:
- Hosted Zone ID (recommended)
- Cluster name
- Unique identifier

### Policy Options

- `sync`: Create and delete records to match Kubernetes resources
- `upsert-only`: Only create/update, never delete
- `create-only`: Only create new records

## Using External DNS

### With Ingress

Annotate your Ingress to create DNS records:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    # External DNS annotation
    external-dns.alpha.kubernetes.io/hostname: app.example.com
    # Optional: set TTL
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
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

### With Service (LoadBalancer)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app.example.com
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: my-app
```

### Multiple Hostnames

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: app.example.com,www.example.com
```

## Verify DNS Records

### Check External DNS Logs

```bash
# Watch External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f

# You should see entries like:
# time="..." level=info msg="Desired change: CREATE app.example.com A"
# time="..." level=info msg="Desired change: CREATE app.example.com TXT"
```

### Check Route53 Records

```bash
# List records in your hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[?Type==`A`]' \
  --output table

# Check TXT records (External DNS ownership)
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[?Type==`TXT`]' \
  --output table
```

### Test DNS Resolution

```bash
# Test DNS resolution (may take a few minutes to propagate)
dig app.example.com
nslookup app.example.com

# Or use curl
curl -I http://app.example.com
```

## Troubleshooting

### Check External DNS Logs

```bash
# View recent logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=100

# Follow logs in real-time
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f
```

### Verify IAM Permissions

```bash
# Check service account annotation
kubectl get sa external-dns -n external-dns -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# Test IAM role permissions (from a pod)
kubectl run -it --rm aws-cli --image=amazon/aws-cli --restart=Never -- \
  aws route53 list-hosted-zones
```

### Common Issues

**Issue: "No hosted zones found"**
- Verify `domainFilters` matches your hosted zone domain
- Check hosted zone exists: `aws route53 list-hosted-zones`
- Ensure IAM role has `route53:ListHostedZones` permission

**Issue: "Access Denied" errors**
- Verify IAM role ARN is correct
- Check IAM role has Route53 permissions
- Verify service account annotation is set correctly

**Issue: DNS records not created**
- Check External DNS logs for errors
- Verify annotations are correct: `external-dns.alpha.kubernetes.io/hostname`
- Ensure domain filter matches your domain
- Check TXT owner ID is set correctly

**Issue: Records created but not accessible**
- Wait for DNS propagation (can take 5-10 minutes)
- Verify LoadBalancer has external IP
- Check DNS points to correct LoadBalancer
- Verify security groups allow traffic

### Debug Mode

Enable debug logging:

```bash
helm upgrade external-dns bitnami/external-dns \
  --namespace external-dns \
  --reuse-values \
  --set logLevel=debug
```

## Advanced Configuration

### Multiple Domains

```bash
helm upgrade external-dns bitnami/external-dns \
  --namespace external-dns \
  --reuse-values \
  --set domainFilters[0]=example.com \
  --set domainFilters[1]=another-domain.com
```

### Private Hosted Zones

For private Route53 hosted zones:

```bash
--set aws.zoneType=private
```

### Source Filters

Only watch specific namespaces:

```bash
--set sources[0]=ingress \
--set sources[1]=service \
--set namespace=default  # Only watch default namespace
```

## Upgrading External DNS

```bash
# Check current version
helm list -n external-dns

# Update repository
helm repo update

# Upgrade to latest version
helm upgrade external-dns bitnami/external-dns \
  --namespace external-dns \
  --reuse-values \
  --version 6.14.4
```

## Uninstalling External DNS

```bash
# Uninstall Helm release
helm uninstall external-dns -n external-dns

# Delete namespace
kubectl delete namespace external-dns

# Note: DNS records in Route53 will remain (they're not deleted automatically)
# To clean up, manually delete records or use AWS CLI
```

## Integration with cert-manager

External DNS works great with cert-manager for automatic TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    # External DNS
    external-dns.alpha.kubernetes.io/hostname: app.example.com
    # cert-manager
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
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

This will:
1. External DNS creates A record: `app.example.com` → LoadBalancer IP
2. cert-manager requests certificate from Let's Encrypt
3. Let's Encrypt validates via HTTP-01 challenge (using the DNS record)
4. Certificate is issued and stored in `app-tls` secret

## Additional Resources

- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [External DNS AWS Provider](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)


