variable "role_name" {
  description = "Name of the IAM role bound to the External Secrets Operator ServiceAccount."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (from the EKS module)."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL (without https://) of the cluster OIDC issuer (from the EKS module)."
  type        = string
}

variable "service_account_namespace" {
  description = "Namespace of the ESO controller ServiceAccount."
  type        = string
  default     = "external-secrets"
}

variable "service_account_name" {
  description = "Name of the ESO controller ServiceAccount (must match the Helm release)."
  type        = string
  default     = "external-secrets"
}

variable "secret_arns" {
  description = "ARNs of the Secrets Manager secrets this role may read. Least privilege — only the app secret(s)."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the IAM role and policy."
  type        = map(string)
  default     = {}
}
