locals {
  cluster_name  = "${var.project}-${var.environment}"
  eso_role_name = "${var.project}-${var.environment}-eso-irsa"

  tags = {
    Project     = var.project
    Owner       = var.owner
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
