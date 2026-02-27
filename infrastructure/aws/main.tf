###############################################################################
# VPC
###############################################################################
module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v1.39.0"

  organization    = var.organization
  account         = var.account
  vpc             = var.vpc
}

###############################################################################
# EKS
###############################################################################
module "eks" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v1.39.0"

  depends_on = [module.vpc]

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
}

###############################################################################
# Route53 DNS
###############################################################################
module "dns" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v1.39.0"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

###############################################################################
# ALB Controller
###############################################################################
module "alb_controller" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/alb_controller?ref=v1.39.0"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
}


###############################################################################
# Istio
###############################################################################
module "istio" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/istio?ref=v1.39.0"
  
  service_type = "LoadBalancer"

depends_on = [module.alb_controller]
}

###############################################################################
# Prometheus
###############################################################################
module "prometheus" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/prometheus?ref=v1.39.0"
}

###############################################################################
# IAM Roles
###############################################################################
module "external_dns_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/external_dns?ref=v1.39.0"

  hosted_zone_public_id            = module.dns.public_zone_id
  hosted_zone_private_id           = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                     = module.eks.eks_cluster_name
}

module "cert_manager_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/cert_manager?ref=v1.39.0"

  hosted_zone_public_id            = module.dns.public_zone_id
  hosted_zone_private_id           = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                     = module.eks.eks_cluster_name
}

module "alb_controller_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/alb_controller?ref=v1.39.0"

  cluster_name                        = module.eks.eks_cluster_name
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
}

module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v1.39.0"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  agent_namespace                     = var.agent_namespace
  cluster_name                        = module.eks.eks_cluster_name

  additional_policies = {
    "static_scopes_policy" = aws_iam_policy.agent_static_scopes.arn
  }
}

###############################################################################
# External DNS
###############################################################################
module "external_dns_public" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v1.39.0"

  depends_on = [module.alb_controller]

  type             = "public"
  zone_type        = "public"
  dns_provider_name = var.dns_provider_name
  domain_filters   = module.dns.public_zone_name
  zone_id_filter   = module.dns.public_zone_id
  policy           = var.policy
  sources          = var.sources
  aws_region       = var.aws_region
  aws_iam_role_arn = module.external_dns_iam.nullplatform_external_dns_role_arn
}

module "external_dns_private" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v1.39.0"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/cert_manager?ref=v1.39.0"

  depends_on = [module.alb_controller]

  cloud_provider    = var.cloud_provider
  aws_sa_arn        = module.cert_manager_iam.nullplatform_cert_manager_role_arn
  hosted_zone_name  = module.dns.public_zone_name
  private_domain_name = module.dns.private_zone_name
  account_slug      = var.organization_slug
  aws_region        = var.aws_region
}

###############################################################################
# Security
###############################################################################
module "security" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/security?ref=v1.39.0"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
  health_check_rules_enabled = true
}

###############################################################################
# Nullplatform Agent API Key
###############################################################################
module "agent_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v1.39.0"

  nrn  = var.nrn
  type = "agent"
}

###############################################################################
# Nullplatform Base
###############################################################################
module "base" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/base?ref=v1.39.0"


  nrn            = var.nrn
  np_api_key     = module.agent_api_key.api_key
  k8s_provider   = var.k8s_provider
  gateway_public_aws_security_group_id  = module.security.public_gateway_security_group_id
  gateway_private_aws_security_group_id = module.security.private_gateway_security_group_id
  gateway_enabled                       = true
  gateway_internal_enabled              = true

  metrics_server_enabled                = true
  
}

###############################################################################
# Nullplatform Agent
###############################################################################
module "agent" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/agent?ref=v1.39.0"

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
  agent_repos_extra       = ["https://github.com/nullplatform/scopes-static-files.git"]

  extra_envs = {
     TOFU_PROVIDER="aws"
     AWS_REGION="Us-east-1"
     TOFU_PROVIDER_BUCKET="tf-state-0269fb2df210b43c"
     NETWORK_LAYER="route53"
     TOFU_LOCK_TABLE="my-lock-table"
     DISTRIBUTION_LAYER="cloudfront"
  }
}
