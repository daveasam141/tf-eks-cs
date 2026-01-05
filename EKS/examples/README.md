# EKS Deployment Examples

This directory contains practical examples to help you learn Kubernetes on EKS.

## Prerequisites

Before running these examples, ensure:
1. Your EKS cluster is running: `kubectl get nodes`
2. All addons are installed: `kubectl get pods -A`

## Examples

### 1. nginx-deployment.yaml
**What it demonstrates**: Basic Deployment and LoadBalancer Service

**Concepts**:
- Deployments: How to run containerized applications
- Replicas: Running multiple copies for availability
- Services: Exposing applications
- LoadBalancer: Creating AWS Load Balancer
- Resource requests/limits: CPU and memory management

**How to use**:
```bash
kubectl apply -f nginx-deployment.yaml

# Wait for Load Balancer (takes 1-2 minutes)
kubectl get svc nginx

# Get the external IP
EXTERNAL_IP=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$EXTERNAL_IP

# Cleanup
kubectl delete -f nginx-deployment.yaml
```

**What to observe**:
- How pods are distributed across nodes
- How the Load Balancer is created in AWS
- How traffic is routed to pods

---

### 2. mysql-with-pvc.yaml
**What it demonstrates**: Persistent Storage with EBS

**Concepts**:
- PersistentVolumeClaim (PVC): Requesting storage
- PersistentVolumes: Actual storage volumes
- EBS CSI Driver: How AWS volumes are created
- Data persistence: Data survives pod restarts
- Secrets: Storing sensitive data

**How to use**:
```bash
# Apply the configuration
kubectl apply -f mysql-with-pvc.yaml

# Wait for pod to be ready
kubectl get pods -l app=mysql

# Create some data
kubectl exec -it deployment/mysql -- mysql -uroot -pMySecurePassword123! -e "CREATE DATABASE testdb;"

# Delete the pod (simulate failure)
kubectl delete pod -l app=mysql

# Wait for new pod
kubectl get pods -l app=mysql

# Verify data still exists
kubectl exec -it deployment/mysql -- mysql -uroot -pMySecurePassword123! -e "SHOW DATABASES;"
# Should see testdb still exists!

# Check the PVC and PV
kubectl get pvc
kubectl get pv

# Cleanup
kubectl delete -f mysql-with-pvc.yaml
```

**What to observe**:
- How EBS volume is created automatically
- How data persists across pod restarts
- Volume attachment to nodes

---

### 3. ingress-example.yaml
**What it demonstrates**: Ingress for Path-Based Routing

**Concepts**:
- Ingress: Routing external traffic
- Path-based routing: Different paths to different services
- NGINX Ingress Controller: How it works
- ClusterIP services: Internal-only services

**How to use**:
```bash
# Apply the configuration
kubectl apply -f ingress-example.yaml

# Get the Ingress address (from NGINX Ingress Controller)
INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test webapp (root path)
curl -H "Host: example.com" http://$INGRESS_IP/

# Test API (api path)
curl -H "Host: example.com" http://$INGRESS_IP/api

# Check Ingress
kubectl get ingress
kubectl describe ingress example-ingress

# Cleanup
kubectl delete -f ingress-example.yaml
```

**What to observe**:
- How one Load Balancer routes to multiple services
- How path-based routing works
- NGINX Ingress Controller configuration

---

### 4. hpa-example.yaml
**What it demonstrates**: Horizontal Pod Autoscaling

**Concepts**:
- Horizontal Pod Autoscaler (HPA): Automatic scaling
- Metrics Server: Collecting resource metrics
- Scaling policies: When and how to scale
- Resource utilization: CPU and memory targets

**How to use**:
```bash
# Apply the configuration
kubectl apply -f hpa-example.yaml

# Check HPA status
kubectl get hpa scalable-app-hpa

# Watch HPA in action
watch kubectl get hpa scalable-app-hpa

# Generate load (in another terminal)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://scalable-app:80; done

# Watch pods scale up
watch kubectl get pods -l app=scalable-app

# Stop load generator (Ctrl+C) and watch scale down
watch kubectl get pods -l app=scalable-app

# Check metrics
kubectl top pods -l app=scalable-app
kubectl top nodes

# Cleanup
kubectl delete -f hpa-example.yaml
```

**What to observe**:
- How HPA monitors metrics
- How pods scale up under load
- How pods scale down when load decreases
- Scaling behavior and timing

---

## Learning Path

1. **Start with nginx-deployment.yaml**: Understand basics
2. **Try mysql-with-pvc.yaml**: Learn about storage
3. **Experiment with ingress-example.yaml**: Understand routing
4. **Explore hpa-example.yaml**: Learn autoscaling

## Advanced Exercises

### Exercise 1: Multi-Tier Application
Deploy a WordPress application with:
- WordPress frontend (Deployment + Service)
- MySQL backend (with PVC)
- Use Ingress to expose WordPress
- Use Secrets for database credentials

### Exercise 2: Microservices
Deploy a simple microservices app:
- Frontend service
- Backend API service
- Database service
- Use Ingress for routing
- Implement service-to-service communication

### Exercise 3: High Availability
- Deploy an app with 5 replicas
- Verify pods are on different nodes
- Simulate node failure
- Observe pod rescheduling

### Exercise 4: Resource Management
- Set appropriate resource requests/limits
- Use HPA for autoscaling
- Monitor resource usage
- Optimize resource allocation

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Services not accessible
```bash
kubectl get svc
kubectl describe svc <service-name>
kubectl get endpoints <service-name>
```

### Storage issues
```bash
kubectl get pvc
kubectl describe pvc <pvc-name>
kubectl get pv
```

### HPA not working
```bash
kubectl get hpa
kubectl describe hpa <hpa-name>
kubectl top pods  # Check if metrics are available
```

## Best Practices

1. **Always set resource requests/limits**: Prevents resource starvation
2. **Use multiple replicas**: For high availability
3. **Use Readiness/Liveness probes**: For better health checks
4. **Use Secrets for sensitive data**: Never hardcode passwords
5. **Use ConfigMaps for configuration**: Separate config from code
6. **Monitor your applications**: Use kubectl top and metrics
7. **Clean up resources**: Delete what you don't need

## Next Steps

After mastering these examples:
1. Deploy a real application
2. Set up CI/CD pipeline
3. Implement monitoring (Prometheus/Grafana)
4. Learn about Service Mesh (Istio)
5. Explore GitOps (ArgoCD)

Happy Learning! 🚀

