output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region the cluster runs in."
  value       = var.region
}

output "kubeconfig_command" {
  description = "Run this to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "eso_irsa_role_arn" {
  description = "ESO IRSA role ARN — inject as REPLACE_ME_ESO_IRSA_ROLE_ARN in the GitOps overlay."
  value       = module.irsa.role_arn
}

output "db_secret_name" {
  description = "Secrets Manager secret name — inject as REPLACE_ME_SECRET_NAME in the GitOps overlay."
  value       = aws_secretsmanager_secret.web_db.name
}

output "db_secret_arn" {
  description = "ARN of the web DB credentials secret."
  value       = aws_secretsmanager_secret.web_db.arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (node group)."
  value       = module.vpc.private_subnet_ids
}
