# =============================================================================
# AWS Lambda scope — assume-role IAM
#
# Unlike S3/RDS (whose permissions are attached directly to the agent role),
# the Lambda scope uses the ASSUME-ROLE pattern: a dedicated role holds the
# Lambda permissions and the agent assumes it (see assume_role_arns on
# module.agent_iam). The agent resolves this role's ARN at runtime via
# ASSUME_ROLE_ARN_DEFAULT (set in the agent's extra_envs).
#
# The role trusts the agent role BY NAME (not by module output) to avoid a
# dependency cycle: module.agent_iam consumes this role's ARN, so this role
# cannot depend on module.agent_iam. The agent role name is the module default
# "nullplatform-{cluster}-agent-role".
#
# Policies mirror scopes-lambda/lambda/specs/tofu/requirements.tf (the upstream
# reference), split in four to stay under the IAM policy size limit.
# =============================================================================

resource "aws_iam_role" "nullplatform_lambda" {
  name = "nullplatform_${module.eks.eks_cluster_name}_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-${module.eks.eks_cluster_name}-agent-role" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# --- Lambda core: manage functions, versions, aliases, concurrency, invoke ---
resource "aws_iam_policy" "nullplatform_lambda_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_lambda_policy"
  description = "Policy for managing Lambda functions provisioned by the scopes-lambda provider"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionConcurrency",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:ListVersionsByFunction",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:InvokeFunction",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:PutProvisionedConcurrencyConfig",
          "lambda:DeleteProvisionedConcurrencyConfig",
          "lambda:GetProvisionedConcurrencyConfig",
          "lambda:GetAccountSettings",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
        ]
        Resource = "*"
      }
    ]
  })
}

# --- IAM management: create/manage Lambda execution roles (scoped) -----------
resource "aws_iam_policy" "nullplatform_lambda_iam_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_lambda_iam_policy"
  description = "Policy for managing IAM execution roles for Lambda scopes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
        ]
        Resource = [
          "arn:aws:iam::*:role/nullplatform-*",
          "arn:aws:iam::*:role/np-lambda-*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

# --- Networking: API Gateway, ALB target groups/listener rules, Route53 ------
resource "aws_iam_policy" "nullplatform_lambda_networking_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_lambda_networking_policy"
  description = "Policy for managing API Gateway, ALB, and Route53 for Lambda scopes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          "apigateway:TagResource",
          "apigateway:UntagResource",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:CreateListenerRule",
          "elasticloadbalancing:DeleteListenerRule",
          "elasticloadbalancing:ModifyListenerRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Storage & observability: ECR, Secrets Manager, CloudWatch, S3 tfstate ---
resource "aws_iam_policy" "nullplatform_lambda_storage_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_lambda_storage_policy"
  description = "Policy for ECR, Secrets Manager, CloudWatch, and S3 tfstate for Lambda scopes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:TagResource",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource",
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:nullplatform/*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Tfstate"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:HeadBucket",
          "s3:PutBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = [
          "arn:aws:s3:::nullplatform-lambda-tfstate-*",
          "arn:aws:s3:::nullplatform-lambda-tfstate-*/*",
        ]
      }
    ]
  })
}

# --- Attach the four policies to the assume-role ----------------------------
resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.nullplatform_lambda.name
  policy_arn = aws_iam_policy.nullplatform_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_iam" {
  role       = aws_iam_role.nullplatform_lambda.name
  policy_arn = aws_iam_policy.nullplatform_lambda_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_networking" {
  role       = aws_iam_role.nullplatform_lambda.name
  policy_arn = aws_iam_policy.nullplatform_lambda_networking_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_storage" {
  role       = aws_iam_role.nullplatform_lambda.name
  policy_arn = aws_iam_policy.nullplatform_lambda_storage_policy.arn
}
