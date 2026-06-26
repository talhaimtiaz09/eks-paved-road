# Thin wrapper over the official VPC module. Public + private subnets across two
# AZs, with exactly ONE NAT gateway (single_nat_gateway) to keep cost down — the
# checklist's hard rule. Private subnets host the EKS nodes; the single NAT gives
# them egress for image pulls and the AWS APIs.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /24 private + /24 public per AZ, carved out of the VPC CIDR.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + 100)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = var.name
  cidr = var.cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true # exactly one NAT gateway — cost rule
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS subnet discovery tags: public subnets for internet-facing LBs, private
  # subnets for internal LBs. We avoid type:LoadBalancer in this project, but the
  # tags are the conventional paved-road default and harmless.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = var.tags
}
