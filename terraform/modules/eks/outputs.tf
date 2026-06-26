output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS control plane API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for the cluster API server."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA. Trust this from service-account roles."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL (without https://) of the cluster OIDC issuer."
  value       = module.eks.oidc_provider
}
