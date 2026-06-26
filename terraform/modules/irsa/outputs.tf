output "role_arn" {
  description = "ARN of the ESO IRSA role. Annotate the ESO ServiceAccount with this (eks.amazonaws.com/role-arn)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the ESO IRSA role."
  value       = aws_iam_role.this.name
}
