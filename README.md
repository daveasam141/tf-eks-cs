# AWS EKS Lab Cluster

This Terraform configuration deploys a cost-effective EKS cluster on AWS for lab/testing purposes.

## Features

- **Cost-Optimized**: Uses Spot instances, single NAT gateway, and minimal node configuration
- **2 Worker Nodes**: t3.medium instances (2 vCPU, 4GB RAM each)
- **Kubernetes 1.28**: Latest stable EKS-supported version
- **High Availability**: Multi-AZ deployment with private subnets
- **AWS Load Balancer Controller**: Automatically provisions AWS Load Balancers (ALB/NLB)
- **EBS CSI Driver**: Enables dynamic provisioning of EBS volumes
- **Longhorn**: Distributed block storage for Kubernetes
- **NGINX Ingress Controller**: Ingress controller with AWS NLB integration

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **Terraform** >= 1.0 installed
   ```bash
   terraform version
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **AWS IAM Permissions**: Your AWS credentials need permissions to create:
   - VPC, Subnets, Internet Gateway, NAT Gateway
   - EKS Cluster and Node Groups
   - EC2 Instances, Security Groups
   - IAM Roles and Policies

## Quick Start

1. **Clone/Copy the configuration files** to your working directory

2. **Create a terraform.tfvars file** (copy from example):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your preferred settings:
   ```hcl
   aws_region         = "us-east-1"
   cluster_name       = "lab-eks-cluster"
   kubernetes_version = "1.28"
   node_instance_type = "t3.medium"  # Options: t3.small, t3.medium, t3.large
   node_count         = 2
   enable_spot_instances = true  # Set to false for on-demand instances
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Review the deployment plan**:
   ```bash
   terraform plan
   ```

6. **Deploy the cluster**:
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

7. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region <your-region> --name <cluster-name>
   ```
   Or use the output command:
   ```bash
   $(terraform output -raw configure_kubectl)
   ```

8. **Verify the cluster**:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

9. **Verify installed components**:
   ```bash
   # Check AWS Load Balancer Controller
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   
   # Check EBS CSI Driver
   kubectl get pods -n kube-system | grep ebs-csi
   
   # Check Longhorn
   kubectl get pods -n longhorn-system
   
   # Check NGINX Ingress
   kubectl get pods -n ingress-nginx
   ```

## Installed Components

### AWS Load Balancer Controller
Automatically provisions and manages AWS Application Load Balancers (ALB) and Network Load Balancers (NLB) for Kubernetes services and ingresses.

**Usage**: Annotate your Service or Ingress with:
```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

### EBS CSI Driver
Enables dynamic provisioning of EBS volumes for PersistentVolumeClaims.

**Usage**: Create a StorageClass or use the default:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
```

### Longhorn
Distributed block storage system for Kubernetes. Provides persistent volumes with replication.

**Access UI**:
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```
Then open http://localhost:8080 in your browser.

**Default StorageClass**: Longhorn creates a default StorageClass. Use it in your PVCs:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### NGINX Ingress Controller
Ingress controller that uses AWS Network Load Balancer (NLB) for external access.

**Get Load Balancer Address**:
```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

**Usage**: Create an Ingress resource:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

## Cost Optimization Features

- **Spot Instances**: Up to 90% savings compared to on-demand (default enabled)
- **Single NAT Gateway**: Shared across all private subnets (saves ~$32/month)
- **t3.medium Instances**: Balanced performance/cost for lab workloads
- **Minimal Node Count**: Only 2 nodes as specified
- **GP3 EBS Volumes**: More cost-effective than GP2

## Estimated Monthly Costs (us-east-1)

- **EKS Control Plane**: ~$73/month (fixed)
- **2x t3.medium Spot Instances**: ~$15-30/month (varies by availability)
- **NAT Gateway**: ~$32/month
- **EBS Volumes**: ~$2/month
- **Load Balancers**: ~$16-20/month per NLB/ALB (only when in use)
- **Data Transfer**: Variable

**Total: ~$120-140/month** (with Spot instances, no active load balancers)

*Note: Costs vary by region and Spot instance availability. On-demand instances would add ~$60/month. Each active Load Balancer adds ~$16-20/month.*

## Configuration Options

### Instance Types (Cost vs Performance)

- `t3.small` (2 vCPU, 2GB RAM) - Cheapest, minimal workloads
- `t3.medium` (2 vCPU, 4GB RAM) - **Recommended for lab** ✅
- `t3.large` (2 vCPU, 8GB RAM) - More memory, slightly more expensive

### Kubernetes Versions

EKS supports Kubernetes versions 1.24 through 1.28. The default is 1.28 (latest stable).

**Note**: Kubernetes 1.33 doesn't exist yet. The latest available version is 1.28.

## Cleanup

To destroy the cluster and all resources:

```bash
terraform destroy
```

**Warning**: This will delete the entire cluster and all workloads. Make sure you have backups if needed.

## Troubleshooting

### Nodes not joining cluster
- Check node group status in AWS Console
- Verify security group rules allow communication
- Check CloudWatch logs for node group issues

### Spot instance interruptions
- Spot instances can be interrupted. For production, use `enable_spot_instances = false`
- Consider using multiple instance types for better Spot availability

### kubectl connection issues
- Verify AWS credentials: `aws sts get-caller-identity`
- Re-run: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- Check security group allows your IP for API server access

## Additional Resources

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/)
- [AWS Spot Instances](https://aws.amazon.com/ec2/spot/)

