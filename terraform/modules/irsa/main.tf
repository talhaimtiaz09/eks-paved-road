# Least-privilege IRSA role for the External Secrets Operator.
#
# Trust: only the ESO controller ServiceAccount (system:serviceaccount:<ns>:<sa>)
# federated through the cluster's OIDC provider may assume this role — no static
# keys anywhere. ESO's SecretStore uses `auth: {}`, so it picks up these creds
# from the annotated ServiceAccount.
#
# Permissions: GetSecretValue + DescribeSecret on the specific app secret ARN(s)
# only. Nothing else in Secrets Manager is readable.

# Trust policy: federated OIDC, scoped to the exact ServiceAccount and audience.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# Permission policy: read only the named app secret(s).
data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid    = "ReadAppSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = var.secret_arns
  }
}

resource "aws_iam_policy" "secrets_read" {
  name   = "${var.role_name}-secrets-read"
  policy = data.aws_iam_policy_document.secrets_read.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.secrets_read.arn
}
