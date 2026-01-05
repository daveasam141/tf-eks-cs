# VPC and Networking
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [for k, v in slice(data.aws_availability_zones.available.names, 0, 2) : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in slice(data.aws_availability_zones.available.names, 0, 2) : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Cost savings: single NAT gateway for lab
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Cluster logging disabled to save costs (for lab environment)
  # To enable in production, uncomment and set: cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_enabled_log_types = []

  # Security: Encryption configuration
  # Use AWS managed encryption keys (cost-effective for lab)
  # Empty cluster_encryption_config means use AWS managed keys
  create_kms_key            = false
  cluster_encryption_config = {}

  # Security: Restrict API server access (optional - set to false for easier lab access)
  # cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # Security: Enable encryption for EBS volumes
  enable_irsa = true # Required for IRSA (IAM Roles for Service Accounts)

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    workers = {
      min_size     = var.enable_cluster_autoscaler ? var.node_min_count : var.node_count
      max_size     = var.enable_cluster_autoscaler ? var.node_max_count : var.node_count
      desired_size = var.node_count

      # Use multiple instance types for better Spot availability
      instance_types = var.enable_spot_instances ? [
        var.node_instance_type,
        replace(var.node_instance_type, "t3", "t3a"), # Add t3a variant for better Spot availability
      ] : [var.node_instance_type]

      capacity_type = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"

      # Spot instance configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_volume_size
            volume_type           = "gp3"
            delete_on_termination = true
            encrypted             = true
          }
        }
      }

      # Labels for pod scheduling
      labels = merge({
        Environment = "lab"
      }, var.node_labels)

      # Taints (optional - uncomment to prevent non-system pods)
      # taints = [
      #   {
      #     key    = "workload"
      #     value  = "general"
      #     effect = "NO_SCHEDULE"
      #   }
      # ]

      tags = merge(var.tags, {
        "k8s.io/cluster-autoscaler/enabled"             = var.enable_cluster_autoscaler ? "true" : "false"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      })
    }
  }

  tags = var.tags
}

# IAM Role for EBS CSI Driver
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# IAM Role for AWS Load Balancer Controller
module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# IAM Role for Cluster Autoscaler
module "cluster_autoscaler_irsa_role" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  attach_cluster_autoscaler_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = var.tags
}


