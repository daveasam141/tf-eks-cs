# EKS Cluster - Quick Start Guide

This is a condensed guide to get you up and running quickly. For detailed explanations, see [README.md](./README.md).

## Prerequisites Checklist

- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.0 installed (`terraform version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] AWS account with appropriate IAM permissions
- [ ] Helm installed (optional but recommended)

## 5-Minute Setup

### 1. Configure Your Cluster

```bash
cd /Users/dasamoah/Documents/mystuff/AWS
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferences (or use defaults).

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes 15-20 minutes)
terraform apply
```

Type `yes` when prompted.

### 3. Connect

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name lab-eks-cluster

# Or use Terraform output
$(terraform output -raw configure_kubectl)

# Verify connection
kubectl get nodes
```

### 4. Verify Components

```bash
# Check all pods are running
kubectl get pods -A

# Check specific components
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl get pods -n kube-system | grep ebs-csi
kubectl get pods -n longhorn-system
kubectl get pods -n ingress-nginx
```

## Try Your First Deployment

```bash
cd EKS/examples
kubectl apply -f nginx-deployment.yaml

# Wait for Load Balancer (1-2 minutes)
kubectl get svc nginx

# Get the external IP and test
EXTERNAL_IP=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$EXTERNAL_IP
```

## Key Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# View all resources
kubectl get all -A

# Check resource usage
kubectl top nodes
kubectl top pods

# View logs
kubectl logs <pod-name> -n <namespace>

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

## Cost Management

**Estimated Monthly Cost**: ~$125/month (with Spot instances, no active load balancers)

**To save money**:
- Use Spot instances (already enabled)
- Single NAT Gateway (already configured)
- Destroy cluster when not using: `terraform destroy`

## Next Steps

1. **Read the full guide**: [README.md](./README.md) - Comprehensive explanations
2. **Try examples**: [examples/README.md](./examples/README.md) - Hands-on exercises
3. **Learn Kubernetes**: [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

## Troubleshooting

**Nodes not ready**:
```bash
# Check node status in AWS Console
# EKS → Your Cluster → Compute → Node Groups
```

**Can't connect to cluster**:
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region us-east-1 --name lab-eks-cluster

# Verify AWS credentials
aws sts get-caller-identity
```

**Pods stuck in Pending**:
```bash
# Check why
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes
```

## Cleanup

When done learning:
```bash
terraform destroy
```

**Warning**: This deletes everything!

---

For detailed explanations and learning, see [README.md](./README.md) 🚀


