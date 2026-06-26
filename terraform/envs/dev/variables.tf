variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name. Used for naming and tagging."
  type        = string
  default     = "eks-paved-road"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "talhaimtiaz09"
}

variable "cluster_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "Instance types for the spot managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of nodes."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes."
  type        = number
  default     = 2
}

variable "cluster_admin_arns" {
  description = "Extra IAM principal ARNs granted cluster-admin (the Terraform caller is added automatically)."
  type        = list(string)
  default     = []
}

variable "db_secret_name" {
  description = "Name of the AWS Secrets Manager secret holding the web app DB credentials. The VALUE is set out-of-band — never in Git or state."
  type        = string
  default     = "eks-paved-road/dev/web-db-credentials"
}
