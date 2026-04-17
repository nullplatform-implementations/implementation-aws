################################################################################
# S3 bucket management policy (aws-s3-bucket service)
################################################################################

# Permissions to create/configure/delete S3 buckets provisioned by the
# aws-s3-bucket service. Scope: any bucket in the account.
resource "aws_iam_policy" "nullplatform_s3_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_s3_policy"
  description = "Policy for managing S3 buckets provisioned by the aws-s3-bucket service"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "s3:PutBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketPolicy",
          "s3:PutBucketTagging",
          "s3:DeleteBucketPolicy",
          "s3:HeadBucket",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:ListAllMyBuckets"
        ],
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
