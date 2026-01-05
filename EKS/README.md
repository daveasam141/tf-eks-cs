# Production-Ready EKS Cluster - Complete Learning Guide

This comprehensive guide will walk you through building a **production-ready but cost-effective** Amazon EKS (Elastic Kubernetes Service) cluster. You'll learn every component, why it's needed, and how it all works together.

## 📚 Table of Contents

1. [What is EKS?](#what-is-eks)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Understanding Each Component](#understanding-each-component)
6. [Production Features Explained](#production-features-explained)
7. [Karpenter vs Cluster Autoscaler](#karpenter-vs-cluster-autoscaler)
8. [Cost Optimization Strategies](#cost-optimization-strategies)
9. [Hands-On Exercises](#hands-on-exercises)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## 🎯 What is EKS?

**Amazon EKS (Elastic Kubernetes Service)** is a managed Kubernetes service that:
- **Manages the Control Plane**: AWS handles the Kubernetes API servers, etcd, and scheduler
- **Provides High Availability**: Control plane runs across multiple AZs automatically
- **Integrates with AWS Services**: Native integration with IAM, VPC, CloudWatch, etc.
- **Reduces Operational Overhead**: No need to manage Kubernetes master nodes yourself

### Why EKS vs Self-Managed Kubernetes?

| Feature | EKS | Self-Managed |
|---------|-----|--------------|
| Control Plane Management | AWS Managed | You Manage |
| High Availability | Built-in | You Configure |
| Security Updates | Automatic | Manual |
| Cost | ~$73/month + nodes | Nodes only |
| Setup Time | Minutes | Days/Weeks |

**For Learning**: EKS lets you focus on Kubernetes itself, not infrastructure management.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                         │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  Public Subnet   │         │  Public Subnet   │          │
│  │   (AZ-1)         │         │   (AZ-2)         │          │
│  │                  │         │                  │          │
│  │  ┌────────────┐  │         │  ┌────────────┐  │          │
│  │  │ NAT Gateway│  │         │  │            │  │          │
│  │  │            │  │         │  │            │  │          │
│  │  └────────────┘  │         │  └────────────┘  │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Private Subnet   │         │ Private Subnet   │          │
│  │   (AZ-1)         │         │   (AZ-2)         │          │
│  │                  │         │                  │          │
│  │  ┌────────────┐  │         │  ┌────────────┐  │          │
│  │  │ EKS Node   │  │         │  │ EKS Node   │  │          │
│  │  │ (t3.medium)│  │         │  │ (t3.medium)│  │          │
│  │  └────────────┘  │         │  └────────────┘  │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         EKS Control Plane (AWS Managed)              │   │
│  │  - API Server (Multi-AZ)                             │   │
│  │  - etcd (Multi-AZ)                                    │   │
│  │  - Scheduler, Controller Manager                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Key Components:

1. **VPC**: Isolated network for your cluster
2. **Public Subnets**: For NAT Gateway and Load Balancers
3. **Private Subnets**: Where your worker nodes run (more secure)
4. **EKS Control Plane**: Managed by AWS across multiple AZs
5. **Worker Nodes**: EC2 instances running your pods
6. **NAT Gateway**: Allows private nodes to access internet (for pulling images)

---

## ✅ Prerequisites

### 1. AWS Account Setup

**Why needed**: You need an AWS account with appropriate permissions.

**Steps**:
```bash
# Install AWS CLI (if not installed)
# macOS:
brew install awscli

# Linux:
sudo apt-get install awscli  # or yum install awscli

# Verify installation
aws --version
```

**Configure AWS Credentials**:
```bash
aws configure
# You'll be prompted for:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

**Verify Access**:
```bash
aws sts get-caller-identity
# Should return your AWS account ID and user ARN
```

**Required IAM Permissions**: Your AWS user/role needs:
- `AmazonEKSFullAccess` (or equivalent)
- `AmazonVPCFullAccess` (or equivalent)
- `AmazonEC2FullAccess` (or equivalent)
- `IAMFullAccess` (or equivalent)

### 2. Terraform Installation

**Why needed**: Terraform is an Infrastructure as Code (IaC) tool that lets you define and manage infrastructure declaratively.

**Installation**:
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform version
```

**Why Terraform?**
- **Reproducible**: Same code = same infrastructure
- **Version Controlled**: Track changes in Git
- **Idempotent**: Safe to run multiple times
- **State Management: Tracks what's actually deployed

### 3. kubectl Installation

**Why needed**: `kubectl` is the command-line tool to interact with Kubernetes clusters.

**Installation**:
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### 4. Helm Installation (Optional but Recommended)

**Why needed**: Helm is a package manager for Kubernetes, making it easy to install complex applications.

**Installation**:
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

---

## 🚀 Step-by-Step Deployment

### Step 1: Navigate to the Project Directory

```bash
cd /Users/dasamoah/Documents/mystuff/AWS
```

### Step 2: Review the Configuration Files

**Understanding the file structure**:

- `provider.tf`: Defines which cloud providers and versions to use
- `main.tf`: Main infrastructure definitions (VPC, EKS cluster, IAM roles)
- `variables.tf`: Input variables you can customize
- `outputs.tf`: Values that will be displayed after deployment
- `addons.tf`: Kubernetes addons and Helm charts
- `terraform.tfvars.example`: Example configuration values

**Let's examine each file**:

#### `provider.tf` - Cloud Provider Configuration

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}
```

**What this does**:
- **Terraform Block**: Specifies minimum Terraform version
- **Required Providers**: Declares which providers to download
  - `aws`: For creating AWS resources (VPC, EKS, EC2, etc.)
  - `kubernetes`: For creating Kubernetes resources (namespaces, deployments, etc.)
  - `helm`: For installing Helm charts

**Why multiple providers?**
- We use `aws` provider to create the EKS cluster
- Once cluster exists, we use `kubernetes` provider to configure it
- `helm` provider lets us install pre-packaged applications

#### `variables.tf` - Customizable Parameters

This file defines what you can customize. Key variables:

- `aws_region`: Where to deploy (affects latency and cost)
- `cluster_name`: Name of your EKS cluster
- `kubernetes_version`: K8s version (1.28 is latest stable for EKS)
- `node_instance_type`: EC2 instance type for worker nodes
- `node_count`: Number of worker nodes
- `enable_spot_instances`: Use cheaper Spot instances (can be interrupted)

#### `main.tf` - Core Infrastructure

This is the heart of the configuration. We'll explain each section in detail below.

### Step 3: Create Your Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars`** with your preferences:

```hcl
aws_region         = "us-east-1"        # Choose closest region
cluster_name       = "my-lab-cluster"   # Your cluster name
kubernetes_version = "1.28"             # Latest stable
node_instance_type = "t3.medium"        # 2 vCPU, 4GB RAM
node_count         = 2                  # Start with 2 nodes
enable_spot_instances = true            # Save money (can be interrupted)

tags = {
  Environment = "lab"
  ManagedBy   = "terraform"
  Project     = "eks-learning"
  Owner       = "your-name"
}
```

**Why these defaults?**
- **t3.medium**: Good balance of cost and performance for learning
- **2 nodes**: Minimum for high availability, keeps costs low
- **Spot instances**: Up to 90% cost savings (acceptable for labs)

### Step 4: Initialize Terraform

```bash
terraform init
```

**What this does**:
1. Downloads the required provider plugins (AWS, Kubernetes, Helm)
2. Downloads Terraform modules (VPC, EKS modules)
3. Sets up the backend (where Terraform stores state)

**Expected output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Finding hashicorp/kubernetes versions matching "~> 2.23"...
- Installing hashicorp/aws v5.x.x...
- Installing hashicorp/kubernetes v2.x.x...
- Installing hashicorp/helm v2.x.x...

Terraform has been successfully initialized!
```

**Understanding Terraform State**:
- Terraform stores state in `terraform.tfstate` (local by default)
- State tracks what resources exist and their IDs
- **Never commit `terraform.tfstate` to Git** (contains sensitive data)
- For production, use remote state (S3 + DynamoDB)

### Step 5: Validate Configuration

```bash
terraform validate
```

**What this does**:
- Checks syntax errors
- Validates variable references
- Ensures provider configurations are correct

**If errors occur**: Fix them before proceeding.

### Step 6: Plan the Deployment

```bash
terraform plan
```

**What this does**:
- Shows you **exactly** what will be created
- Calculates costs (in some cases)
- Highlights any issues before deployment

**Review the plan carefully**:
- Look for unexpected resources
- Check instance types and counts
- Verify region and tags

**Example output**:
```
Plan: 45 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_name = "my-lab-cluster"
  + cluster_endpoint = (known after apply)
```

**Key resources that will be created**:
1. VPC and networking (subnets, route tables, internet gateway)
2. NAT Gateway (for private subnet internet access)
3. Security Groups (firewall rules)
4. EKS Cluster (control plane)
5. EKS Node Group (worker nodes)
6. IAM Roles and Policies
7. EBS CSI Driver addon
8. AWS Load Balancer Controller
9. Longhorn (storage)
10. NGINX Ingress Controller

### Step 7: Deploy the Cluster

```bash
terraform apply
```

**What happens**:
1. Terraform prompts you to confirm: Type `yes`
2. Resources are created in order (dependencies respected)
3. Progress is shown in real-time
4. Takes **15-20 minutes** (EKS cluster creation is slow)

**Timeline**:
- **0-5 min**: VPC, subnets, NAT Gateway
- **5-15 min**: EKS control plane creation
- **15-20 min**: Worker nodes joining cluster
- **20-25 min**: Addons and Helm charts installing

**Watch for errors**:
- If something fails, Terraform will show the error
- Most common: IAM permissions, region availability, resource limits

### Step 8: Configure kubectl

After deployment completes, configure `kubectl` to connect to your cluster:

```bash
# Use the output command
aws eks update-kubeconfig --region us-east-1 --name my-lab-cluster

# Or use Terraform output
$(terraform output -raw configure_kubectl)
```

**What this does**:
- Creates/updates `~/.kube/config` file
- Adds your EKS cluster as a context
- Sets up authentication using AWS IAM

**Verify connection**:
```bash
kubectl get nodes
```

**Expected output**:
```
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.us-east-1.compute.internal     Ready    <none>   5m    v1.28.x
ip-10-0-2-xxx.us-east-1.compute.internal     Ready    <none>   5m    v1.28.x
```

**If nodes show "NotReady"**: Wait a few minutes, they're still initializing.

### Step 9: Verify All Components

```bash
# Check cluster info
kubectl cluster-info

# Check all pods (should see addons running)
kubectl get pods -A

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check EBS CSI Driver
kubectl get pods -n kube-system | grep ebs-csi

# Check Longhorn
kubectl get pods -n longhorn-system

# Check NGINX Ingress
kubectl get pods -n ingress-nginx
```

**All pods should show "Running" status**. If some are "Pending" or "Error", see Troubleshooting section.

---

## 🔍 Understanding Each Component

### 1. VPC (Virtual Private Cloud)

**What it is**: Your isolated network in AWS.

**Why needed**:
- Isolates your cluster from other AWS resources
- Controls network traffic (security groups, NACLs)
- Defines IP address ranges

**Key components**:
- **CIDR Block**: `10.0.0.0/16` (65,536 IP addresses)
- **Availability Zones**: 2 AZs for high availability
- **Public Subnets**: For NAT Gateway, Load Balancers
- **Private Subnets**: For worker nodes (more secure)

**Why private subnets for nodes?**
- Nodes don't need direct internet access
- More secure (can't be directly accessed from internet)
- Still can access internet via NAT Gateway (for pulling container images)

### 2. NAT Gateway

**What it is**: Allows resources in private subnets to access the internet.

**Why needed**:
- Worker nodes need to pull container images from Docker Hub, ECR, etc.
- Nodes need to download security updates
- Applications might need external API access

**Cost**: ~$32/month + data transfer
- **Why single NAT Gateway?**: Cost savings (multi-AZ NAT = $64/month)
- **Trade-off**: Single point of failure (acceptable for lab)

### 3. EKS Control Plane

**What it is**: The "brain" of your Kubernetes cluster.

**Components** (all managed by AWS):
- **API Server**: Handles all API requests
- **etcd**: Stores cluster state
- **Scheduler**: Decides which node runs which pod
- **Controller Manager**: Ensures desired state

**Why managed?**
- AWS handles updates, backups, scaling
- High availability built-in (multi-AZ)
- You focus on applications, not infrastructure

**Cost**: ~$73/month (fixed, regardless of usage)

### 4. Worker Nodes (EC2 Instances)

**What they are**: The "workers" that run your applications.

**Instance Type: t3.medium**
- **vCPUs**: 2
- **RAM**: 4GB
- **Network**: Up to 5 Gbps
- **Cost**: ~$0.0416/hour on-demand, ~$0.0125/hour spot

**Why t3.medium?**
- Good balance for learning workloads
- Burstable performance (can burst CPU)
- Enough resources for multiple pods

**Spot Instances**:
- **What**: Unused EC2 capacity at discount
- **Savings**: Up to 90% off on-demand
- **Risk**: Can be interrupted with 2-minute warning
- **For labs**: Perfect (acceptable risk for cost savings)

### 5. EBS CSI Driver

**What it is**: Allows Kubernetes to dynamically create EBS volumes.

**Why needed**:
- Applications need persistent storage
- EBS volumes can be attached to pods
- Automatically creates/deletes volumes as needed

**How it works**:
1. You create a PersistentVolumeClaim (PVC)
2. EBS CSI Driver creates an EBS volume
3. Volume is attached to your pod
4. Data persists even if pod is deleted

**Example**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
```

### 6. AWS Load Balancer Controller

**What it is**: Automatically creates AWS Load Balancers for Kubernetes Services/Ingresses.

**Why needed**:
- Expose applications to the internet
- Distribute traffic across pods
- Integrates with AWS (ALB, NLB)

**How it works**:
1. You create a Service with type `LoadBalancer` or an Ingress
2. Controller watches for these resources
3. Automatically creates AWS Load Balancer
4. Configures routing to your pods

**Example**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  ports:
    - port: 80
  selector:
    app: my-app
```

### 7. Longhorn

**What it is**: Distributed block storage for Kubernetes.

**Why needed**:
- Provides replicated storage
- Better than EBS for some use cases (distributed, self-healing)
- Great for learning distributed systems

**Features**:
- **Replication**: Data copied across multiple nodes
- **Self-Healing**: Automatically recovers from failures
- **Web UI**: Visual management interface

**Access UI**:
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

### 8. NGINX Ingress Controller

**What it is**: Routes external traffic to services based on hostname/path.

**Why needed**:
- Single entry point for multiple services
- SSL/TLS termination
- Path-based routing

**How it works**:
1. Ingress Controller runs as a pod
2. Creates AWS NLB (Network Load Balancer)
3. Routes traffic based on Ingress rules

**Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
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

---

## 🏭 Production Features Explained

### 1. High Availability

**What we have**:
- **Multi-AZ Deployment**: Nodes in 2 availability zones
- **EKS Control Plane**: Automatically multi-AZ (AWS managed)
- **Replicated Storage**: Longhorn replicates data

**Why important**:
- If one AZ fails, cluster continues running
- No single point of failure
- Production workloads require this

### 2. Security

**Network Security**:
- **Private Subnets**: Nodes not directly accessible from internet
- **Security Groups**: Firewall rules controlling traffic
- **NAT Gateway**: Only outbound internet access

**IAM Integration**:
- **IRSA (IAM Roles for Service Accounts)**: Pods can assume IAM roles
- **Least Privilege**: Each component has only needed permissions
- **No Hardcoded Credentials**: Uses IAM roles

**Encryption**:
- **EBS Volumes**: Encrypted at rest
- **In-Transit**: TLS for API server communication

### 3. Scalability

**Horizontal Pod Autoscaling** (can be added):
- Automatically scales pods based on CPU/memory
- Requires Metrics Server (usually pre-installed)

**Cluster Autoscaler** (tags configured, can be installed):
- Automatically adds/removes nodes based on demand
- Saves costs when cluster is idle

**Manual Scaling**:
```bash
# Scale a deployment
kubectl scale deployment my-app --replicas=5

# Or edit node group size in Terraform
```

### 4. Monitoring (Optional - Adds Cost)

**CloudWatch Container Insights**:
- Detailed metrics and logs
- Cost: ~$0.10 per GB of log data ingested

**To enable** (add to `main.tf`):
```hcl
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]
```

**Alternative**: Use Prometheus + Grafana (free, self-hosted)

---

## 🚀 Karpenter vs Cluster Autoscaler

This setup supports **both Karpenter and Cluster Autoscaler**, but **Karpenter is recommended** for modern EKS clusters.

### Quick Comparison

| Feature | Karpenter | Cluster Autoscaler |
|---------|-----------|-------------------|
| Scaling Speed | 30-90 seconds | 2-5 minutes |
| Configuration | Simple (NodePool) | Complex (ASG) |
| Instance Selection | Dynamic, optimal | Pre-defined groups |
| Cost Optimization | Automatic | Manual |

### Enable Karpenter

In `terraform.tfvars`:

```hcl
enable_karpenter = true
enable_cluster_autoscaler = false  # Don't use both!
```

**For detailed Karpenter documentation, see [KARPENTER.md](./KARPENTER.md)**

### Why Karpenter?

1. **Faster**: Provisions nodes in 30-90 seconds vs 2-5 minutes
2. **Smarter**: Automatically selects optimal instance types
3. **Simpler**: No need to manage Auto Scaling Groups
4. **Cost-Effective**: Better consolidation and Spot handling

---

## 💰 Cost Optimization Strategies

### Current Configuration Costs (us-east-1)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| EKS Control Plane | ~$73 | Fixed cost |
| 2x t3.medium Spot | ~$18 | Varies by availability |
| NAT Gateway | ~$32 | Single gateway |
| EBS Volumes (20GB) | ~$2 | GP3 volumes |
| Load Balancers | ~$16-20 each | Only when in use |
| **Total (idle)** | **~$125/month** | No active load balancers |

### Cost Optimization Tips

1. **Use Spot Instances** ✅ (Already configured)
   - Savings: Up to 90%
   - Risk: Can be interrupted (acceptable for labs)

2. **Single NAT Gateway** ✅ (Already configured)
   - Savings: ~$32/month vs multi-AZ
   - Trade-off: Single point of failure

3. **Right-Size Instances**
   - Start small (t3.medium)
   - Monitor usage, scale up if needed
   - Use `kubectl top nodes` to check resource usage

4. **Delete When Not Using**
   ```bash
   terraform destroy  # Saves money when not learning
   ```

5. **Use Reserved Instances** (for long-term)
   - 1-year term: ~40% savings
   - 3-year term: ~60% savings
   - Only if running 24/7

6. **Monitor Costs**
   - AWS Cost Explorer
   - Set up billing alerts
   - Tag resources for cost tracking

### Cost Comparison

| Scenario | Monthly Cost |
|----------|--------------|
| **Current (Spot, Single NAT)** | ~$125 |
| On-Demand Instances | ~$185 |
| Multi-AZ NAT Gateway | ~$157 |
| Production Setup (On-Demand, Multi-AZ) | ~$220 |

---

## 🎓 Hands-On Exercises

### Exercise 1: Deploy Your First Application

**Goal**: Deploy a simple web application and expose it.

**Steps**:

1. **Create a deployment**:
```bash
cat > nginx-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

kubectl apply -f nginx-deployment.yaml
```

2. **Create a service**:
```bash
cat > nginx-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: nginx
EOF

kubectl apply -f nginx-service.yaml
```

3. **Get the load balancer address**:
```bash
kubectl get svc nginx
# Wait for EXTERNAL-IP to be assigned (takes 1-2 minutes)
# Then curl the address or open in browser
```

4. **Verify it works**:
```bash
# Get the load balancer address
EXTERNAL_IP=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$EXTERNAL_IP
```

**What you learned**:
- Deployments: How to run applications
- Services: How to expose applications
- Load Balancers: How AWS integrates with Kubernetes

### Exercise 2: Use Persistent Storage

**Goal**: Deploy an app that uses persistent storage.

**Steps**:

1. **Create a PVC using EBS**:
```bash
cat > mysql-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
EOF

kubectl apply -f mysql-pvc.yaml
```

2. **Verify storage**:
```bash
# Check PVC
kubectl get pvc

# Check PV (PersistentVolume)
kubectl get pv

# Check pod is running
kubectl get pods -l app=mysql
```

3. **Test persistence**:
```bash
# Create some data
kubectl exec -it deployment/mysql -- mysql -uroot -ppassword -e "CREATE DATABASE testdb;"

# Delete the pod
kubectl delete pod -l app=mysql

# Wait for new pod
kubectl get pods -l app=mysql

# Verify data still exists
kubectl exec -it deployment/mysql -- mysql -uroot -ppassword -e "SHOW DATABASES;"
# Should still see testdb
```

**What you learned**:
- PersistentVolumeClaims: How to request storage
- EBS CSI Driver: How it creates volumes automatically
- Data persistence: Data survives pod restarts

### Exercise 3: Use Ingress

**Goal**: Route traffic using Ingress (instead of LoadBalancer service).

**Steps**:

1. **Deploy an application**:
```bash
kubectl create deployment webapp --image=nginx:latest
kubectl expose deployment webapp --port=80 --type=ClusterIP
```

2. **Create Ingress**:
```bash
cat > webapp-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: webapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp
            port:
              number: 80
EOF

kubectl apply -f webapp-ingress.yaml
```

3. **Get Ingress address**:
```bash
kubectl get ingress
# Note the ADDRESS

# Test (replace ADDRESS with actual value)
curl -H "Host: webapp.example.com" http://<INGRESS-ADDRESS>
```

**What you learned**:
- Ingress: Path/host-based routing
- NGINX Ingress Controller: How it works
- Multiple services behind one load balancer

### Exercise 4: Scale Applications

**Goal**: Learn horizontal scaling.

**Steps**:

1. **Scale a deployment**:
```bash
kubectl scale deployment nginx --replicas=5
kubectl get pods -l app=nginx
```

2. **Watch pods distribute across nodes**:
```bash
kubectl get pods -l app=nginx -o wide
# Notice pods are on different nodes
```

3. **Check resource usage**:
```bash
kubectl top nodes
kubectl top pods
```

**What you learned**:
- Horizontal scaling: Adding more pod replicas
- Pod distribution: Kubernetes spreads pods across nodes
- Resource monitoring: How to check usage

---

## 🔧 Troubleshooting Guide

### Problem: Nodes Not Joining Cluster

**Symptoms**:
```bash
kubectl get nodes
# Shows no nodes or nodes in NotReady state
```

**Solutions**:

1. **Check node group status in AWS Console**:
   - Go to EKS → Your Cluster → Compute → Node Groups
   - Look for errors

2. **Check security groups**:
   - Nodes need to communicate with control plane
   - Control plane security group must allow nodes

3. **Check IAM roles**:
   - Node group IAM role needs proper permissions
   - Should have `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, etc.

4. **Check CloudWatch logs**:
   ```bash
   aws logs tail /aws/eks/my-lab-cluster/cluster --follow
   ```

### Problem: Pods Stuck in Pending

**Symptoms**:
```bash
kubectl get pods
# Pods show Pending status
```

**Solutions**:

1. **Check why pod is pending**:
   ```bash
   kubectl describe pod <pod-name>
   # Look for "Events" section
   ```

2. **Common causes**:
   - **Insufficient resources**: Not enough CPU/memory on nodes
   - **No storage**: PVC can't be bound
   - **Node selector**: Pod requires specific node labels
   - **Taints**: Nodes have taints that pod can't tolerate

3. **Check node resources**:
   ```bash
   kubectl describe nodes
   kubectl top nodes
   ```

### Problem: Can't Connect to Cluster

**Symptoms**:
```bash
kubectl get nodes
# Error: unable to connect to server
```

**Solutions**:

1. **Verify AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Reconfigure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name my-lab-cluster
   ```

3. **Check security group**:
   - Control plane security group must allow your IP
   - Check "Authorized networks" in EKS console

4. **Verify cluster exists**:
   ```bash
   aws eks describe-cluster --name my-lab-cluster --region us-east-1
   ```

### Problem: Spot Instance Interrupted

**Symptoms**:
- Pods suddenly terminating
- Nodes disappearing

**Solutions**:

1. **This is expected with Spot instances**:
   - AWS gives 2-minute warning
   - Pods are rescheduled to other nodes

2. **For production**: Set `enable_spot_instances = false` in `terraform.tfvars`

3. **Use multiple instance types** (advanced):
   ```hcl
   instance_types = ["t3.medium", "t3a.medium", "t3.small"]
   # Better Spot availability
   ```

### Problem: Load Balancer Not Created

**Symptoms**:
```bash
kubectl get svc
# EXTERNAL-IP shows <pending>
```

**Solutions**:

1. **Check AWS Load Balancer Controller**:
   ```bash
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. **Check IAM role**:
   - Controller needs proper IAM permissions
   - Verify IRSA role is attached

3. **Check subnet tags**:
   - Public subnets need: `kubernetes.io/role/elb = "1"`
   - Private subnets need: `kubernetes.io/role/internal-elb = "1"`

### Problem: Storage Issues

**Symptoms**:
- PVC stuck in Pending
- Pods can't mount volumes

**Solutions**:

1. **Check EBS CSI Driver**:
   ```bash
   kubectl get pods -n kube-system | grep ebs-csi
   kubectl logs -n kube-system deployment/ebs-csi-controller
   ```

2. **Check IAM role**:
   - EBS CSI Driver needs IAM permissions
   - Verify IRSA role

3. **Check availability zones**:
   - EBS volumes must be in same AZ as node
   - Use `volumeBindingMode: WaitForFirstConsumer` in StorageClass

---

## 📖 Additional Learning Resources

### Official Documentation
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Hands-On Practice
- [Kubernetes Basics Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [EKS Workshop](https://www.eksworkshop.com/)

### Cost Management
- [AWS Cost Calculator](https://calculator.aws/)
- [EKS Pricing](https://aws.amazon.com/eks/pricing/)

---

## 🎯 Next Steps

Now that you have a working EKS cluster, here's what to explore next:

1. **Deploy Real Applications**:
   - WordPress with MySQL
   - Microservices application
   - CI/CD pipeline (Jenkins, GitLab CI)

2. **Learn Advanced Topics**:
   - Service Mesh (Istio, Linkerd)
   - GitOps (ArgoCD, Flux)
   - Monitoring (Prometheus, Grafana)
   - Logging (ELK Stack, Loki)

3. **Security Hardening**:
   - Pod Security Standards
   - Network Policies
   - Secrets Management (AWS Secrets Manager)
   - Image Scanning

4. **Cost Optimization**:
   - Cluster Autoscaler
   - Right-sizing instances
   - Reserved Instances

5. **Multi-Cluster**:
   - Deploy multiple clusters
   - Federation
   - Disaster recovery

---

## 🧹 Cleanup

When you're done learning, destroy the cluster to save costs:

```bash
# Review what will be deleted
terraform plan -destroy

# Destroy everything
terraform destroy

# Type 'yes' when prompted
```

**Warning**: This deletes everything! Make sure you don't need any data.

---

## 📝 Summary

You've learned:
- ✅ How to deploy a production-ready EKS cluster
- ✅ Understanding of each component and why it's needed
- ✅ Cost optimization strategies
- ✅ Hands-on Kubernetes experience
- ✅ Troubleshooting skills

**Congratulations!** You now have a solid foundation in EKS and Kubernetes. Keep experimenting and building!

---

## 💬 Questions?

Common questions and answers:

**Q: Can I use this for production?**
A: Almost! You'd want to:
- Use on-demand instances (or mixed)
- Enable multi-AZ NAT Gateway
- Enable CloudWatch logging
- Add monitoring (Prometheus/Grafana)
- Implement network policies
- Use proper secrets management

**Q: How do I update Kubernetes version?**
A: Update `kubernetes_version` in `terraform.tfvars` and run `terraform apply`. EKS supports in-place upgrades.

**Q: Can I add more nodes?**
A: Yes! Update `node_count` in `terraform.tfvars` or use Cluster Autoscaler for automatic scaling.

**Q: How do I backup my cluster?**
A: Use Velero for backup/restore. It can backup cluster state, persistent volumes, etc.

---

Happy Learning! 🚀

