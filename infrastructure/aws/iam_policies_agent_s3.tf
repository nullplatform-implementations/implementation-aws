################################################################################
# S3 bucket management policy (aws-s3-bucket service)
################################################################################

# Permissions to create/configure/delete S3 buckets provisioned by the
# aws-s3-bucket service. Scope: any bucket in the account.
resource "aws_iam_policy" "nullplatform_s3_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_s3_policy"
  description = "Policy for managing S3 buckets provisioned by the aws-s3-bucket service"

  # The AWS provider (v6+) refreshes aws_s3_bucket by reading a wide surface of
  # bucket attributes (ACL, CORS, Logging, Lifecycle, Replication, etc.).
  # Enumerating each s3:Get* action is brittle, so we grant s3:* scoped to the
  # same wildcard resource already chosen. If a tighter scope is ever needed,
  # narrow the Resource (e.g. arn:aws:s3:::np-*) rather than the Action list.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:*",
        "Resource" : "*"
      }
    ]
  })
}

################################################################################
# IAM management policy (per-link IAM users + access keys)
################################################################################

# Permissions to create/manage IAM users per link (see permissions/main.tf in
# the aws-s3-bucket service). Scope: any IAM user.
resource "aws_iam_policy" "nullplatform_s3_iam_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_s3_iam_policy"
  description = "Policy for managing per-link IAM users and access keys for S3 bucket access"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:ListUserTags",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:GetUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies"
        ],
        "Resource" : "*"
      }
    ]
  })
}
