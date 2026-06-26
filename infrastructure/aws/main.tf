###############################################################################
# VPC
###############################################################################
module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v4.5.2"

  organization = var.organization
  account      = var.account
  vpc          = var.vpc
}

###############################################################################
# EKS
# v1.54.0 adds the aws-ebs-csi-driver addon + gp3 StorageClass (default),
# demoting the legacy gp2 in-tree class. The module now ships its own
# kubernetes provider internally, which forbids depends_on/count/for_each on
# the caller block — ordering vs. module.vpc is already guaranteed by the
# aws_vpc_vpc_id / aws_subnets_private_ids references below.
###############################################################################
module "eks" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v4.5.2"

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Bump node count from 2 to 3 to give the cluster overhead for node drains
  # (istiod HA + rolling updates). Current 2-node cluster is saturated.
  node_group_min_size     = 3
  node_group_desired_size = 3

  # Pin AMI to avoid rolling drift on every plan. Current state value.
  ami_release_version            = "1.34.6-20260415"
  use_latest_ami_release_version = false
}

###############################################################################
# Route53 DNS
###############################################################################
module "dns" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v4.5.2"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

###############################################################################
# ALB Controller
###############################################################################
module "alb_controller" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/aws_load_balancer_controller?ref=v4.5.2"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
}


###############################################################################
# Istio
###############################################################################
module "istio" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/istio?ref=v4.5.2"

  service_type    = "LoadBalancer"
  istiod_replicas = 2

  depends_on = [module.alb_controller]
}

###############################################################################
# Prometheus
###############################################################################
module "prometheus" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/prometheus?ref=v4.5.2"
}

###############################################################################
# IAM Roles
###############################################################################
module "external_dns_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/external_dns?ref=v4.5.2"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "cert_manager_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/cert_manager?ref=v4.5.2"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "alb_controller_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/aws_load_balancer_controller_iam?ref=v4.5.2"

  cluster_name                        = module.eks.eks_cluster_name
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
}

module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v4.5.2"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  agent_namespace                     = var.agent_namespace
  cluster_name                        = module.eks.eks_cluster_name

  additional_policies = {
    "static_scopes_policy"      = aws_iam_policy.agent_static_scopes.arn
    "rds_policy"                = aws_iam_policy.nullplatform_rds_policy.arn
    "rds_secret_manager_policy" = aws_iam_policy.nullplatform_rds_secretsmanager_policy.arn
    "rds_s3_policy"             = aws_iam_policy.nullplatform_rds_s3_policy.arn
    "rds_sg_policy"             = aws_iam_policy.nullplatform_rds_sg_policy.arn
    "s3_policy"                 = aws_iam_policy.nullplatform_s3_policy.arn
    "s3_iam_policy"             = aws_iam_policy.nullplatform_s3_iam_policy.arn
  }

  # Lambda scope uses assume-role: the agent assumes this dedicated role
  # (defined in iam_lambda_assume_role.tf) instead of holding Lambda
  # permissions directly. The rest of the scopes/services stay on
  # additional_policies above (direct permissions).
  assume_role_arns = [aws_iam_role.nullplatform_lambda.arn]
}

module "ci_build_workflow_user" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ci-build-workflow-user?ref=feat/separate-build-user-from-asset-repositories"

  cluster_name = module.eks.eks_cluster_name
}

module "ecr_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ecr?ref=feat/separate-build-user-from-asset-repositories"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
}

module "s3_assets_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/s3-assets?ref=feat/separate-build-user-from-asset-repositories"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
  assets_bucket             = "lambda-files-aws-services"
}

###############################################################################
# External DNS
###############################################################################
module "external_dns_public" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v4.5.2"

  depends_on = [module.alb_controller]

  type              = "public"
  zone_type         = "public"
  dns_provider_name = var.dns_provider_name
  domain_filters    = module.dns.public_zone_name
  zone_id_filter    = module.dns.public_zone_id
  policy            = var.policy
  sources           = var.sources
  aws_region        = var.aws_region
  aws_iam_role_arn  = module.external_dns_iam.nullplatform_external_dns_role_arn
}

module "external_dns_private" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v4.5.2"

  depends_on = [module.alb_controller, module.external_dns_public]

  type              = "private"
  zone_type         = "private"
  create_namespace  = false
  dns_provider_name = var.dns_provider_name
  domain_filters    = module.dns.private_zone_name
  zone_id_filter    = module.dns.private_zone_id
  policy            = var.policy
  sources           = var.sources
  aws_region        = var.aws_region
  aws_iam_role_arn  = module.external_dns_iam.nullplatform_external_dns_role_arn
}

###############################################################################
# Cert Manager
###############################################################################
module "cert_manager" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/cert_manager?ref=v4.5.2"

  depends_on = [module.alb_controller]

  cloud_provider      = var.cloud_provider
  aws_sa_arn          = module.cert_manager_iam.nullplatform_cert_manager_role_arn
  hosted_zone_name    = module.dns.public_zone_name
  private_domain_name = module.dns.private_zone_name
  account_slug        = var.organization_slug
  aws_region          = var.aws_region
}

###############################################################################
# Security
###############################################################################
module "security" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/security?ref=v4.5.2"

  depends_on = [module.eks]

  cluster_name               = module.eks.eks_cluster_name
  vpc_id                     = module.vpc.vpc_id
  health_check_rules_enabled = true
  gateway_internal_enabled   = true
  cluster_security_group_id  = module.eks.eks_cluster_primary_security_group_id
  gateway_port               = 443
}

###############################################################################
# Nullplatform Agent API Key
###############################################################################
module "agent_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v4.5.2"

  nrn  = var.nrn
  type = "agent"
}

###############################################################################
# Nullplatform Base
###############################################################################
module "base" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/base?ref=v4.5.2"

  np_api_key                            = module.agent_api_key.api_key
  k8s_provider                          = var.k8s_provider
  gateway_public_aws_security_group_id  = module.security.public_gateway_security_group_id
  gateway_private_aws_security_group_id = module.security.private_gateway_security_group_id
  gateway_enabled                       = true
  gateway_internal_enabled              = true
  gateway_public_aws_name               = "k8s-np-aws-services-public"
  gateway_internal_aws_name             = "k8s-np-aws-services-int"

  metrics_server_enabled = true

}

###############################################################################
# Nullplatform Agent
###############################################################################
module "agent" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/agent?ref=v4.5.2"

  depends_on = [module.base]

  api_key          = module.agent_api_key.api_key
  cluster_name     = module.eks.eks_cluster_name
  nrn              = var.nrn
  tags_selectors   = var.tags_selectors
  image_tag        = var.image_tag
  cloud_provider   = var.cloud_provider
  aws_iam_role_arn = module.agent_iam.nullplatform_agent_role_arn
  dns_type         = var.dns_type

  service_template        = var.service_template
  initial_ingress_path    = var.initial_ingress_path
  blue_green_ingress_path = var.blue_green_ingress_path
  agent_repos_scope       = "https://github.com/nullplatform/scopes.git"
  agent_repos_extra = [
    "https://github.com/nullplatform/scopes-static-files.git#main",
    "https://github.com/nullplatform/services.git#main",
    "https://github.com/nullplatform/services-s-3.git#main",
    "https://github.com/nullplatform/services-postgresql-k-8-s.git#proposal/align-with-services-s-3",
    "https://github.com/nullplatform/scopes-lambda.git#main"
  ]
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
