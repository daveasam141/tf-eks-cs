variable "aws_region" {
  description = "AWS region for EKS cluster"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "lab-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.33" # Latest stable version (1.33 doesn't exist yet)
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium" # Cost-effective for lab, 2 vCPU, 4GB RAM
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "enable_spot_instances" {
  description = "Use Spot instances for cost savings (recommended for lab)"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler (automatically scales nodes). Note: You can also install Karpenter separately using Helm or Ansible."
  type        = bool
  default     = false
}

variable "node_min_count" {
  description = "Minimum number of worker nodes (for autoscaler)"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of worker nodes (for autoscaler)"
  type        = number
  default     = 4
}

variable "node_volume_size" {
  description = "Size of EBS volume for worker nodes (GB)"
  type        = number
  default     = 20
}

variable "node_labels" {
  description = "Additional labels for worker nodes"
  type        = map(string)
  default     = {}
}


