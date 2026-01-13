# Install GP3 Storage Class on EKS

This guide explains how to install and configure the GP3 storage class for Amazon EKS. GP3 is AWS's latest generation of General Purpose SSD volumes, offering better price/performance than GP2.

## What is GP3?

**GP3 (General Purpose SSD 3)** is AWS's latest EBS volume type that provides:
- **Better price/performance**: 20% lower cost per GB than GP2
- **Baseline performance**: 3,000 IOPS and 125 MB/s throughput (vs GP2's 3 IOPS/GB)
- **Independent scaling**: Can scale IOPS and throughput independently of volume size
- **Encryption**: Supports encryption at rest

## Prerequisites

Before installing GP3 storage class, ensure you have:

- [ ] EKS cluster running
- [ ] `kubectl` configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- [ ] **EBS CSI Driver installed** (required for dynamic provisioning)
- [ ] Cluster admin permissions

### Verify EBS CSI Driver is Installed

```bash
# Check if EBS CSI Driver is installed
kubectl get daemonset -n kube-system | grep ebs-csi

# Or check addons
aws eks describe-addon \
  --cluster-name <your-cluster-name> \
  --addon-name aws-ebs-csi-driver \
  --region <your-region>
```

**If EBS CSI Driver is NOT installed:**

The EBS CSI Driver is required for GP3 to work. Install it first:

```bash
# Using AWS EKS Addon (Recommended)
aws eks create-addon \
  --cluster-name <your-cluster-name> \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<account-id>:role/AmazonEKS_EBS_CSI_DriverRole \
  --region <your-region>

# Or using Helm
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system
```

## Installation Steps

### Step 1: Create GP3 StorageClass Manifest

Create a file `storageclass-gp3.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  # Optional: specify IOPS (default: 3000, max: 16000)
  # iops: "3000"
  # Optional: specify throughput (default: 125, max: 1000)
  # throughput: "125"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**Key Parameters Explained:**

- **`name: gp3`**: Name of the storage class
- **`is-default-class: "true"`**: Makes GP3 the default storage class (PVCs without `storageClassName` will use this)
- **`provisioner: ebs.csi.aws.com`**: Uses the EBS CSI Driver
- **`type: gp3`**: Specifies GP3 volume type
- **`encrypted: "true"`**: Enables encryption at rest (uses AWS-managed keys)
- **`volumeBindingMode: WaitForFirstConsumer`**: Waits to create volume until pod is scheduled (cost optimization)
- **`allowVolumeExpansion: true`**: Allows PVCs to be expanded later

**Optional Performance Tuning:**

If you need higher performance, uncomment and adjust:

```yaml
parameters:
  type: gp3
  encrypted: "true"
  iops: "4000"        # 3,000-16,000 IOPS (default: 3000)
  throughput: "250"   # 125-1,000 MB/s (default: 125)
```

**Note**: Higher IOPS/throughput increases cost.

### Step 2: Apply the StorageClass

```bash
# Apply the storage class
kubectl apply -f storageclass-gp3.yaml

# Verify it was created
kubectl get storageclass
```

**Expected Output:**

```
NAME            PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp3 (default)   ebs.csi.aws.com   Delete          WaitForFirstConsumer   true                   5s
gp2             ebs.csi.aws.com   Delete          Immediate              true                   1h
```

The `(default)` annotation indicates GP3 is now the default storage class.

### Step 3: Verify Installation

```bash
# Get detailed information
kubectl describe storageclass gp3
```

**Expected Output:**

```
Name:            gp3
IsDefaultClass:  Yes
Annotations:     storageclass.kubernetes.io/is-default-class=true
Provisioner:     ebs.csi.aws.com
Parameters:      encrypted=true,type=gp3
AllowVolumeExpansion:  True
VolumeBindingMode:      WaitForFirstConsumer
```

## Testing GP3 Storage Class

### Test 1: Create a PVC

```bash
# Create a test PVC
cat > test-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-gp3-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3  # Explicitly specify (or omit to use default)
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f test-pvc.yaml

# Check PVC status
kubectl get pvc test-gp3-pvc

# Wait for it to be Bound (it will be Pending until a pod uses it)
kubectl get pvc test-gp3-pvc -w
```

**Note**: With `WaitForFirstConsumer`, the PVC will remain `Pending` until a pod actually uses it. This is normal and saves costs.

### Test 2: Create a Pod Using the PVC

```bash
# Create a test pod
cat > test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-gp3-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-gp3-pvc
EOF

kubectl apply -f test-pod.yaml

# Check pod status
kubectl get pod test-gp3-pod

# Now check PVC - it should be Bound
kubectl get pvc test-gp3-pvc
```

**Expected Output:**

```
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-gp3-pvc    Bound    pvc-12345678-1234-1234-1234-123456789abc   10Gi       RWO            gp3            2m
```

### Test 3: Verify EBS Volume in AWS

```bash
# Get the PV name
kubectl get pv

# Get volume ID from PV
VOLUME_ID=$(kubectl get pv $(kubectl get pvc test-gp3-pvc -o jsonpath='{.spec.volumeName}') -o jsonpath='{.spec.csi.volumeHandle}')

# Check volume in AWS
aws ec2 describe-volumes --volume-ids $VOLUME_ID --region <your-region>

# Verify it's GP3
aws ec2 describe-volumes --volume-ids $VOLUME_ID --region <your-region> --query 'Volumes[0].VolumeType'
# Should output: "gp3"
```

### Test 4: Clean Up Test Resources

```bash
# Delete test resources
kubectl delete pod test-gp3-pod
kubectl delete pvc test-gp3-pvc
kubectl delete -f test-pvc.yaml test-pod.yaml 2>/dev/null || true
```

## Using GP3 in Your Applications

### Example: MySQL with GP3 Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3  # Uses GP3 storage class
  resources:
    requests:
      storage: 20Gi
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
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

### Example: Using Default Storage Class

If GP3 is set as default, you can omit `storageClassName`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  # storageClassName: gp3  # Not needed - uses default
  resources:
    requests:
      storage: 10Gi
```

## Performance Tuning

### Custom IOPS and Throughput

For applications that need higher performance, create a custom storage class:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-high-performance
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  iops: "8000"        # Higher IOPS
  throughput: "500"   # Higher throughput
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**Use it in your PVC:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: high-perf-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-high-performance
  resources:
    requests:
      storage: 100Gi
```

**Cost Note**: Higher IOPS/throughput increases cost. Only use when needed.

## Troubleshooting

### Issue: PVC Stays in Pending State

**Symptom:**
```bash
kubectl get pvc
NAME            STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
my-pvc          Pending                                      gp3            5m
```

**Cause**: With `WaitForFirstConsumer`, PVCs stay Pending until a pod uses them.

**Solution**: This is normal. Create a pod that uses the PVC, and it will be bound.

### Issue: EBS CSI Driver Not Found

**Symptom:**
```
Error: storageclass.storage.k8s.io "gp3" is invalid: provisioner: Required value
```

**Solution**: Install EBS CSI Driver (see Prerequisites section).

### Issue: Volume Creation Fails

**Symptom:**
```
Events:
  Warning  ProvisioningFailed  persistentvolumeclaim/my-pvc  failed to provision volume with StorageClass "gp3": rpc error: code = Internal desc = Could not create volume "pvc-xxx": could not create volume in EC2: UnauthorizedOperation
```

**Cause**: EBS CSI Driver service account doesn't have proper IAM permissions.

**Solution**: Ensure IRSA (IAM Roles for Service Accounts) is configured for EBS CSI Driver.

```bash
# Check service account
kubectl get sa ebs-csi-controller-sa -n kube-system

# Verify IAM role annotation
kubectl get sa ebs-csi-controller-sa -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### Issue: Cannot Expand Volume

**Symptom:**
```
Error: persistentvolumeclaim "my-pvc" is invalid: spec.resources.requests.storage: Forbidden: field is immutable
```

**Cause**: You're trying to edit the PVC directly.

**Solution**: Use `kubectl patch` or edit the PVC to increase size:

```bash
# Method 1: Patch
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Method 2: Edit
kubectl edit pvc my-pvc
# Change storage: 10Gi to storage: 20Gi
```

## Cost Comparison: GP3 vs GP2

| Volume Size | GP2 Cost (per month) | GP3 Cost (per month) | Savings |
|-------------|---------------------|----------------------|---------|
| 10 GiB      | ~$1.00              | ~$0.80               | 20%     |
| 100 GiB     | ~$10.00             | ~$8.00               | 20%     |
| 1 TiB       | ~$100.00            | ~$80.00              | 20%     |

**Note**: GP3 also provides better baseline performance (3,000 IOPS vs GP2's 3 IOPS/GB for volumes < 1 TiB).

## Best Practices

1. **Use `WaitForFirstConsumer`**: Saves costs by only creating volumes when needed
2. **Enable encryption**: Always use `encrypted: "true"` for production
3. **Set as default**: If GP3 is your primary storage, set it as default
4. **Monitor costs**: Use AWS Cost Explorer to track EBS spending
5. **Right-size volumes**: Start small and expand as needed (GP3 supports expansion)
6. **Use appropriate IOPS**: Only increase IOPS/throughput if your application needs it

## Summary

You've successfully installed GP3 storage class on your EKS cluster! GP3 provides:
- ✅ Better price/performance than GP2
- ✅ Independent IOPS/throughput scaling
- ✅ Encryption at rest
- ✅ Volume expansion support
- ✅ Cost optimization with `WaitForFirstConsumer`

Your applications can now use GP3 storage by specifying `storageClassName: gp3` in their PVCs, or by using it as the default storage class.

## Next Steps

- [ ] Test GP3 with a real application
- [ ] Monitor EBS costs in AWS Cost Explorer
- [ ] Consider creating custom storage classes for different performance tiers
- [ ] Set up volume snapshots for backup (if needed)
