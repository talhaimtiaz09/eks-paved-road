variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC the cluster is deployed into."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the node group (private subnets)."
  type        = list(string)
}

variable "instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "capacity_type" {
  description = "Capacity type for the node group: SPOT (cost) or ON_DEMAND."
  type        = string
  default     = "SPOT"
}

variable "node_min_size" {
  description = "Minimum nodes in the managed node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired nodes in the managed node group."
  type        = number
  default     = 1
}

variable "cluster_admin_arns" {
  description = "IAM principal ARNs granted cluster-admin via EKS access entries (e.g. your deploying user/role)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all EKS resources."
  type        = map(string)
  default     = {}
}
