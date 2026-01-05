# Karpenter - Modern Node Autoscaling for EKS

## What is Karpenter?

**Karpenter** is AWS's modern, open-source node autoscaler for Kubernetes. It's designed specifically for AWS EKS and provides **significant advantages** over the traditional Cluster Autoscaler.

## Why Karpenter vs Cluster Autoscaler?

| Feature | Karpenter | Cluster Autoscaler |
|---------|-----------|-------------------|
| **Scaling Speed** | 30-90 seconds | 2-5 minutes |
| **Instance Selection** | Dynamic, optimal for each pod | Pre-defined node groups |
| **Configuration** | Simple (NodePool + EC2NodeClass) | Complex (ASG management) |
| **Cost Optimization** | Automatic instance type selection | Manual configuration |
| **Spot Handling** | Built-in interruption handling | Requires additional setup |
| **Node Consolidation** | Automatic | Limited |

### Key Advantages

1. **Faster Scaling**: Directly provisions EC2 instances without Auto Scaling Groups
2. **Smart Instance Selection**: Chooses optimal instance types based on pod requirements
3. **Better Cost Optimization**: Automatically selects cost-effective instances
4. **Simpler Configuration**: No need to pre-define node groups
5. **Built-in Spot Support**: Handles Spot interruptions gracefully

## How Karpenter Works

```
┌─────────────────────────────────────────────────────────┐
│  Pod Pending (needs resources)                           │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Karpenter Controller                                    │
│  - Analyzes pod requirements                             │
│  - Selects optimal instance type                         │
│  - Provisions EC2 instance                               │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  EC2 Instance Created (30-90 seconds)                   │
│  - Joins cluster                                        │
│  - Pod scheduled                                         │
└─────────────────────────────────────────────────────────┘
```

## Configuration in This Setup

### 1. Enable Karpenter

In `terraform.tfvars`:

```hcl
enable_karpenter = true
enable_cluster_autoscaler = false  # Don't use both!
```

### 2. Components Created

When Karpenter is enabled, the following are created:

1. **IAM Role**: `karpenter-controller` role with permissions to create EC2 instances
2. **IAM Instance Profile**: For nodes that Karpenter creates
3. **SQS Queue**: For Spot instance interruption notifications
4. **EventBridge Rules**: To send interruption events to SQS
5. **Helm Release**: Karpenter controller deployment
6. **NodePool**: Defines node constraints and requirements
7. **EC2NodeClass**: Defines EC2 configuration (instance types, AMI, etc.)

### 3. Node Group Strategy

With Karpenter enabled:
- **Static Node Group**: Reduced to 1 node (for system pods)
- **Dynamic Nodes**: Karpenter creates nodes on-demand for application pods

This approach:
- Keeps system pods running on stable nodes
- Allows Karpenter to optimize application workloads
- Reduces costs (only pay for what you need)

## NodePool Configuration

The NodePool defines:
- **Instance Types**: Which EC2 types Karpenter can use
- **Capacity Types**: Spot vs On-Demand
- **Limits**: Maximum CPU/memory across all nodes
- **Disruption**: How aggressively to consolidate nodes

Example from our configuration:

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]  # Prefer Spot, fallback to On-Demand
  - key: node.kubernetes.io/instance-type
    operator: In
    values: ["t3.small", "t3.medium", "t3.large", ...]
limits:
  cpu: "1000"
  memory: "1000Gi"
```

## EC2NodeClass Configuration

The EC2NodeClass defines:
- **Subnets**: Where to launch instances
- **Security Groups**: Network access
- **AMI**: Which AMI to use (AL2, Bottlerocket, etc.)
- **Storage**: EBS volume configuration
- **IAM Instance Profile**: For node permissions

## Spot Instance Handling

Karpenter has built-in Spot interruption handling:

1. **SQS Queue**: Receives interruption warnings (2-minute notice)
2. **EventBridge**: Monitors for interruption events
3. **Automatic Replacement**: Karpenter provisions replacement nodes before termination
4. **Pod Migration**: Kubernetes reschedules pods to new nodes

This provides **seamless Spot instance usage** with minimal disruption.

## Cost Optimization Features

### 1. Instance Right-Sizing

Karpenter selects the **smallest instance** that fits your pod requirements:

```
Pod needs: 2 CPU, 4GB RAM
Karpenter selects: t3.medium (2 vCPU, 4GB) ✅
Not: t3.large (2 vCPU, 8GB) ❌
```

### 2. Node Consolidation

Karpenter automatically consolidates nodes:
- Moves pods to fewer, larger nodes
- Terminates underutilized nodes
- Saves costs when cluster is idle

### 3. Spot Instance Optimization

- Prefers Spot instances (up to 90% savings)
- Automatically handles interruptions
- Falls back to On-Demand if Spot unavailable

## Usage Examples

### Example 1: Scale Up on Demand

```bash
# Deploy a workload that needs more resources
kubectl apply -f large-workload.yaml

# Watch Karpenter create nodes
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

### Example 2: Check NodePool Status

```bash
# List NodePools
kubectl get nodepools

# Describe NodePool
kubectl describe nodepool default

# List EC2NodeClasses
kubectl get ec2nodeclasses

# Describe EC2NodeClass
kubectl describe ec2nodeclass default
```

### Example 3: Monitor Karpenter

```bash
# Check Karpenter pods
kubectl get pods -n karpenter

# View Karpenter metrics (if metrics server enabled)
kubectl top pods -n karpenter

# Check Karpenter events
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

## Customizing Karpenter

### Modify NodePool

Edit the NodePool to change instance types or limits:

```bash
kubectl edit nodepool default
```

Or update `karpenter.tf` and run `terraform apply`.

### Add Multiple NodePools

Create different NodePools for different workloads:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: gpu-workloads
spec:
  template:
    spec:
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["g4dn.xlarge", "g4dn.2xlarge"]
```

Then label your pods:
```yaml
spec:
  nodeSelector:
    karpenter.sh/nodepool: gpu-workloads
```

## Troubleshooting

### Karpenter Not Creating Nodes

1. **Check IAM Permissions**:
   ```bash
   kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
   # Look for IAM permission errors
   ```

2. **Verify NodePool**:
   ```bash
   kubectl get nodepool default -o yaml
   kubectl describe nodepool default
   ```

3. **Check EC2NodeClass**:
   ```bash
   kubectl get ec2nodeclass default -o yaml
   kubectl describe ec2nodeclass default
   ```

4. **Verify Subnet/Security Group Tags**:
   ```bash
   # Subnets and security groups need:
   # karpenter.sh/discovery = <cluster-name>
   ```

### Nodes Created But Pods Not Scheduled

1. **Check Node Labels**:
   ```bash
   kubectl get nodes --show-labels
   ```

2. **Check Pod Requirements**:
   ```bash
   kubectl describe pod <pod-name>
   # Look for "Unschedulable" events
   ```

### Spot Interruptions Not Handled

1. **Check SQS Queue**:
   ```bash
   aws sqs get-queue-attributes \
     --queue-url <queue-url> \
     --attribute-names All
   ```

2. **Verify EventBridge Rules**:
   ```bash
   aws events list-rules --name-prefix <cluster-name>-karpenter
   ```

## Best Practices

1. **Start Small**: Begin with conservative limits, increase as needed
2. **Use Spot Instances**: Enable for cost savings (acceptable for labs)
3. **Monitor Costs**: Use AWS Cost Explorer to track spending
4. **Set Appropriate Limits**: Prevent runaway costs
5. **Use Multiple NodePools**: For different workload types
6. **Enable Consolidation**: Let Karpenter optimize node usage

## Cost Comparison

### With Karpenter (Spot Instances)
- **Static Node**: 1x t3.medium Spot = ~$9/month
- **Dynamic Nodes**: On-demand, only when needed
- **Total**: ~$100-120/month (idle) to ~$150-200/month (active)

### Without Karpenter (Static Nodes)
- **2x t3.medium**: Always running = ~$18/month (Spot) or ~$60/month (On-Demand)
- **Total**: ~$125/month (Spot) or ~$185/month (On-Demand)

**Karpenter saves money** by:
- Using fewer nodes when idle
- Right-sizing instances
- Preferring Spot instances
- Consolidating nodes automatically

## Migration from Cluster Autoscaler

If you're currently using Cluster Autoscaler:

1. **Enable Karpenter**:
   ```hcl
   enable_karpenter = true
   enable_cluster_autoscaler = false
   ```

2. **Apply Changes**:
   ```bash
   terraform apply
   ```

3. **Verify Karpenter is Working**:
   ```bash
   kubectl get pods -n karpenter
   kubectl get nodepools
   ```

4. **Scale Down Old Node Groups** (optional):
   - Karpenter will handle new workloads
   - Old node groups can be kept for existing pods
   - Or migrate pods gradually

## Additional Resources

- [Karpenter Documentation](https://karpenter.sh/)
- [AWS EKS Best Practices - Karpenter](https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html)
- [Karpenter GitHub](https://github.com/aws/karpenter)

---

**Karpenter is the recommended choice for EKS node autoscaling!** It's faster, simpler, and more cost-effective than Cluster Autoscaler. 🚀


