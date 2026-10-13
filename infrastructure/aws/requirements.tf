###############################################################################
# Cloud-side prerequisites every scope, service and parameter provider needs
# before the agent can run its actions: IAM roles to assume, the Lambda ALB,
# KMS policies. Each ref must match the version pinned in nullplatform/locals.tf.
###############################################################################

module "scope_requirements_k8s" {
  source = "git::https://github.com/nullplatform/scopes.git//k8s/specs/requirements/aws?ref=v1.16.2"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

# Existing wildcard cert (*.<domain>) reused for the Lambda ALB HTTPS listener,
# so we don't mint a second wildcard alongside the one already issued.
data "aws_acm_certificate" "wildcard" {
  domain      = "*.${local.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

module "scope_requirements_lambda" {
  source = "git::https://github.com/nullplatform/scopes-lambda.git//lambda/specs/requirements?ref=v0.7.2"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn

  # Opt-in public ALB for exposing Lambda over HTTP.
  install_alb     = true
  vpc_id          = module.vpc.vpc_id
  certificate_arn = data.aws_acm_certificate.wildcard.arn
}

module "scope_requirements_static_files" {
  source = "git::https://github.com/nullplatform/scopes-static-files.git//static-files/specs/requirements/aws?ref=v1.1.5"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

# Read-only access to the mobile binaries bucket and the mobile/ secrets.
# Keep this ref equal to version/tag of mobile_store_definition in
# nullplatform/locals.tf: both pin the same scopes-mobile-store release.
module "scope_requirements_mobile_store" {
  source = "git::https://github.com/nullplatform/scopes-mobile-store.git//mobile-store/specs/requirements/aws?ref=v0.5.0"

  cluster_name       = module.eks.eks_cluster_name
  agent_role_arn     = local.agent_role_arn
  assets_bucket_name = aws_s3_bucket.assets_mobile.bucket
}

module "service_requirements_s3" {
  source = "git::https://github.com/nullplatform/services-s-3.git//aws-s3-bucket/specs/requirements/aws?ref=v0.2.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "service_requirements_dynamodb" {
  source = "git::https://github.com/nullplatform/services-dynamo-db.git//dynamodb/specs/requirements/aws?ref=v0.3.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "service_requirements_rds_server" {
  source = "git::https://github.com/nullplatform/services-postgresql-rds.git//rds-postgres-server/specs/requirements/aws?ref=v0.2.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "service_requirements_rds_db" {
  source = "git::https://github.com/nullplatform/services-postgresql-rds.git//rds-postgres-db/specs/requirements/aws?ref=v0.2.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "parameter_store_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-parameter-store/specs/requirements?ref=v0.3.0"

  iam_role = var.iam_role
}

module "secrets_manager_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-secrets-manager/specs/requirements?ref=v0.3.0"

  iam_role = var.secrets_manager_iam_role
}



###############################################################################
# S3 Bucket - Static Assets
###############################################################################
resource "aws_s3_bucket" "assets" {
  provider = aws.sa_east_1
  bucket   = "assets-aws-services-main-sao-paulo"
}

resource "aws_s3_bucket_policy" "static" {
  provider = aws.sa_east_1
  bucket   = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

###############################################################################
# ACM Certificate - Wildcard for static scopes (CloudFront requires us-east-1)
###############################################################################
# resource "aws_acm_certificate" "wildcard" {
#   domain_name       = "*.${local.domain_name}"
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_record" "wildcard_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = module.dns.public_zone_id
# }

# resource "aws_acm_certificate_validation" "wildcard" {
#   certificate_arn         = aws_acm_certificate.wildcard.arn
#   validation_record_fqdns = [for record in aws_route53_record.wildcard_validation : record.fqdn]
# }


###############################################################################
# S3 Bucket - Mobile binaries (mobile-store scope POC)
# Private: the CI writes it through the build workflow group (module.s3_iam_mobile)
# and the mobile-store scope reads it with its own requirements role.
###############################################################################
resource "aws_s3_bucket" "assets_mobile" {
  bucket = "assets-aws-mobile"
}

resource "aws_s3_bucket_public_access_block" "assets_mobile" {
  bucket                  = aws_s3_bucket.assets_mobile.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets_mobile" {
  bucket = aws_s3_bucket.assets_mobile.id
  versioning_configuration {
    status = "Enabled"
  }
}
