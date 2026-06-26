variable "name" {
  description = "Name prefix for the VPC and its resources (typically the cluster name)."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used to tag subnets for Kubernetes load-balancer discovery."
  type        = string
}

variable "cidr" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across. EKS requires at least two."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "EKS needs subnets in at least two Availability Zones."
  }
}

variable "tags" {
  description = "Tags applied to all VPC resources."
  type        = map(string)
  default     = {}
}
