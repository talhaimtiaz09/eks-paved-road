# dev environment root — wires the modules together:
#   vpc  -> network with one NAT gateway
#   eks  -> cluster + OIDC + one spot t3.small node group
#   secret container in Secrets Manager (value out-of-band)
#   irsa -> least-privilege role for ESO, trusting the cluster OIDC provider
#
# Cluster-less by default: `terraform init -backend=false && terraform validate`.
# Nothing here is applied until you explicitly run `terraform apply`.

module "vpc" {
  source = "../../modules/vpc"

  name         = local.cluster_name
  cluster_name = local.cluster_name
  cidr         = var.vpc_cidr
  tags         = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  instance_types    = var.node_instance_types
  capacity_type     = "SPOT"
  node_desired_size = var.node_desired_size
  node_min_size     = var.node_min_size
  node_max_size     = var.node_max_size

  cluster_admin_arns = var.cluster_admin_arns

  tags = local.tags
}

# Secret CONTAINER only — Terraform never sets the value, so no credential ever
# touches Git or state. Populate it out-of-band after apply, e.g.:
#   aws secretsmanager put-secret-value \
#     --secret-id eks-paved-road/dev/web-db-credentials \
#     --secret-string '{"username":"webuser","password":"<choose>"}'
resource "aws_secretsmanager_secret" "web_db" {
  name        = var.db_secret_name
  description = "Web app DB credentials (JSON: username/password). Value set out-of-band, never in Git/state."

  # Short recovery window so teardown leaves nothing lingering between sessions.
  recovery_window_in_days = 0

  tags = local.tags
}

module "irsa" {
  source = "../../modules/irsa"

  role_name         = local.eso_role_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # ESO controller ServiceAccount created by the Helm chart.
  service_account_namespace = "external-secrets"
  service_account_name      = "external-secrets"

  # Least privilege: only the one app secret.
  secret_arns = [aws_secretsmanager_secret.web_db.arn]

  tags = local.tags
}
