# Remote state in S3 with a DynamoDB lock table. This is the ONLY stack left
# running permanently (it costs pennies); the cluster itself is destroyed at the
# end of every session.
#
# The bucket + table are created ONCE by a separate backend-bootstrap step (see
# README → "State backend"). Values are supplied at init time via a partial
# backend config so nothing account-specific is committed:
#
#   terraform init \
#     -backend-config="bucket=<your-state-bucket>" \
#     -backend-config="key=eks-paved-road/dev/terraform.tfstate" \
#     -backend-config="region=us-east-1" \
#     -backend-config="dynamodb_table=<your-lock-table>" \
#     -backend-config="encrypt=true"
#
# For cluster-less fmt/validate work, initialise without a backend:
#   terraform init -backend=false
terraform {
  backend "s3" {}
}
