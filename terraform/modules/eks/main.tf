# Thin wrapper over the official EKS module (v20). It enables the OIDC provider
# (enable_irsa) so the External Secrets Operator can assume an IAM role with no
# static keys (see modules/irsa). One spot t3.small managed node group keeps the
# cluster cheap. Access is managed with EKS access entries (no aws-auth configmap),
# so no Kubernetes provider is required here.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Public API endpoint so kubectl/argocd port-forward works from a workstation;
  # nodes stay in private subnets. We never expose workloads via LoadBalancer.
  cluster_endpoint_public_access = true

  enable_irsa = true # OIDC provider for IRSA

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Grant the identity running Terraform cluster-admin, plus any extra admins.
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for arn in var.cluster_admin_arns : arn => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      capacity_type  = var.capacity_type # SPOT

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = var.subnet_ids
    }
  }

  tags = var.tags
}
