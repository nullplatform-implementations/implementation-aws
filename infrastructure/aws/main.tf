###############################################################################
# VPC
###############################################################################
module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v7.2.1"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v7.2.1"

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  aws_profile                  = var.aws_profile

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v7.2.1"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

###############################################################################
# ALB Controller
###############################################################################
module "alb_controller" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/aws_load_balancer_controller?ref=v7.2.1"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
}


###############################################################################
# Istio
###############################################################################
module "istio" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/istio?ref=v7.2.1"

  istiod_replicas = 2

  depends_on = [module.alb_controller]
}

###############################################################################
# Prometheus
###############################################################################
module "prometheus" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/prometheus?ref=v7.2.1"

  # Pinned to the chart version already deployed.
  prometheus_version = "28.16.0"
}

###############################################################################
# IAM Roles
###############################################################################
module "external_dns_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/external_dns?ref=v7.2.1"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "cert_manager_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/cert_manager?ref=v7.2.1"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "alb_controller_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/aws_load_balancer_controller_iam?ref=v7.2.1"

  cluster_name                        = module.eks.eks_cluster_name
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
}

module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v7.2.1"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  agent_namespace                     = var.agent_namespace
  cluster_name                        = module.eks.eks_cluster_name

  assume_role_arns = [
    module.scope_requirements_lambda.permissions_role_arn,
    module.scope_requirements_k8s.permissions_role_arn,
    module.scope_requirements_static_files.permissions_role_arn,
    module.service_requirements_s3.permissions_role_arn,
    module.service_requirements_dynamodb.permissions_role_arn,
    module.service_requirements_rds_server.permissions_role_arn,
    module.service_requirements_rds_db.permissions_role_arn,
    module.parameter_store_requirements.iam_role_arn,
    module.secrets_manager_requirements.iam_role_arn
  ]
}

module "scope_requirements_k8s" {
  source = "git::https://github.com/nullplatform/scopes.git//k8s/specs/requirements/aws?ref=v1.15.1"

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
  source = "git::https://github.com/nullplatform/scopes-lambda.git//lambda/specs/requirements?ref=v0.5.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn

  # Opt-in public ALB for exposing Lambda over HTTP.
  install_alb     = true
  vpc_id          = module.vpc.vpc_id
  certificate_arn = data.aws_acm_certificate.wildcard.arn
}

module "scope_requirements_static_files" {
  source = "git::https://github.com/nullplatform/scopes-static-files.git//static-files/specs/requirements/aws?ref=v0.5.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "service_requirements_s3" {
  source = "git::https://github.com/nullplatform/services-s-3.git//aws-s3-bucket/specs/requirements/aws?ref=v0.2.0"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

module "service_requirements_dynamodb" {
  source = "git::https://github.com/nullplatform/services-dynamo-db.git//dynamodb/specs/requirements/aws?ref=v0.2.0"

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


module "ci_build_workflow_user" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ci-build-workflow-user?ref=v7.2.1"

  cluster_name = module.eks.eks_cluster_name
}

module "ecr_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ecr?ref=v7.2.1"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
}

module "s3_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/s3?ref=v7.2.1"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
  bucket                    = "lambda-files-aws-services"
}

###############################################################################
# External DNS
###############################################################################
module "external_dns_public" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v7.2.1"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v7.2.1"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/cert_manager?ref=v7.2.1"

  depends_on = [module.alb_controller]

  cloud_provider      = var.cloud_provider
  aws_sa_arn          = module.cert_manager_iam.nullplatform_cert_manager_role_arn
  hosted_zone_name    = module.dns.public_zone_name
  private_domain_name = module.dns.private_zone_name
  account_slug        = var.organization_slug
  aws_region          = var.aws_region

  # Pinned to the chart version already deployed.
  cert_manager_version = "v1.20.2"
}

###############################################################################
# Security
###############################################################################
module "security" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/security?ref=v7.2.1"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v7.2.1"

  nrn  = var.nrn
  type = "agent"
}

###############################################################################
# Nullplatform Base
###############################################################################

# The base chart (2.40.0) only renders the gateways Namespace when it does not
# exist yet (`lookup`), so the first upgrade after the install drops it from
# the release and Helm deletes it, taking the Gateways, their pods and load
# balancers with it (2026-09-03). Owning the namespace here keeps it out of
# the release for good.
resource "kubernetes_namespace" "gateways" {
  metadata {
    name   = "gateways"
    labels = { name = "gateways" }
  }
}

module "base" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/base?ref=v7.2.1"

  depends_on = [kubernetes_namespace.gateways]

  np_api_key                            = module.agent_api_key.api_key
  k8s_provider                          = var.k8s_provider
  gateway_public_aws_security_group_id  = module.security.public_gateway_security_group_id
  gateway_private_aws_security_group_id = module.security.private_gateway_security_group_id
  gateway_enabled                       = true
  gateway_internal_enabled              = true
  gateway_public_aws_name               = "k8s-np-aws-services-public"
  gateway_internal_aws_name             = "k8s-np-aws-services-int"

  metrics_server_enabled = true

  # v7.2 requires every version pinned. Chart: what is already deployed.
  # Images were running :latest (unresolvable to a tag), so they take the
  # versions VERSIONS.md documents; the logs controller DaemonSet rolls once.
  nullplatform_base_helm_version = "2.40.0"
  logging_controller_image_tag   = "1.6.0"
  control_plane_agent_image_tag  = "0.9.2"

  # Chart 2.40.0's CRD job is a no-op once the CRDs exist; keep it off, as the
  # release ran before v7.2.1, until the fixed chart lands (helm-charts#183).
  install_gateway_v2_crd = false
}

###############################################################################
# Nullplatform Agent
###############################################################################
module "agent" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/agent?ref=v7.2.1"

  depends_on = [module.base]

  api_key                         = module.agent_api_key.api_key
  tags_selectors                  = var.tags_selectors
  image_tag                       = var.image_tag
  nullplatform_agent_helm_version = var.agent_helm_version
  agent_traffic_manager_tag       = var.traffic_manager_tag
  cloud_provider                  = var.cloud_provider
  aws_iam_role_arn                = module.agent_iam.nullplatform_agent_role_arn
  dns_type                        = var.dns_type

  service_template        = var.service_template
  initial_ingress_path    = var.initial_ingress_path
  blue_green_ingress_path = var.blue_green_ingress_path

  # Reap a package's worker pod after 15 minutes without commands (the agent
  # recreates it on the next package-exec), and require mTLS between the agent
  # and its workers: the chart defaults to plaintext, which lets any pod that
  # reaches a worker run commands with the agent's IAM identity.
  worker = {
    idleTTL  = "15m"
    security = "mtls"

    # The agent takes a worker's image from the package revision attached to the
    # action. Scopes created before the containers package existed carry none,
    # so the containers worker is pinned here to the same image the package
    # publishes. A pin is trusted and matched by package slug.
    pins = [
      {
        package = "containers"
        image   = "public.ecr.aws/nullplatform/scopes/containers@${var.containers_worker_image_digest}"
      },
      {
        package = "static-scope"
        image   = "public.ecr.aws/nullplatform/scopes/static-files@${var.static_files_worker_image_digest}"
      },
      {
        package = "aws-lambda-agustin"
        image   = "public.ecr.aws/nullplatform/scopes/lambda@${var.lambda_worker_image_digest}"
      }
    ]

    # The lambda image ships scopes-lambda alone; the ALB and Route53 steps live
    # in scopes-networking, which the legacy channel passed as --overrides-path.
    # worker-bridge derives that flag from NP_OVERRIDES_PATH, so an init
    # container fetches the pinned tag into a volume shared with the worker.
    patches = [
      {
        target = { package = "aws-lambda-agustin" }
        merge = {
          spec = {
            volumes = [{ name = "overrides", emptyDir = {} }]
            # Keep every string here short: the agent module re-indents the
            # yamlencode output line by line, and a folded long string ends up
            # with a literal newline inside it.
            initContainers = [{
              name         = "fetch-overrides"
              image        = "public.ecr.aws/docker/library/alpine:3.20"
              env          = [{ name = "SRC", value = "https://github.com/nullplatform/scopes-networking/archive/refs/tags/${var.scopes_networking_version}.tar.gz" }]
              command      = ["sh", "-c", "wget -qO- \"$SRC\" | tar -xzC /overrides --strip-components=1"]
              volumeMounts = [{ name = "overrides", mountPath = "/overrides" }]
            }]
            containers = [{
              name         = "worker"
              volumeMounts = [{ name = "overrides", mountPath = "/app/overrides", readOnly = true }]
              env          = [{ name = "NP_OVERRIDES_PATH", value = "/app/overrides/lambda" }]
            }]
          }
        }
      }
    ]
  }

  # Packages whose worker pods run with the agent's ServiceAccount (IRSA) and
  # enough memory for tofu. Slugs, not catalog keys.
  worker_orchestrated_packages = [
    "containers",
    "static-scope",
    "aws-s3-bucket-agent-k8s",
    "rds-postgres-server-agustin-test",
    "rds-postgres-database-agustin-test",
    "aws-lambda-agustin",
  ]

  # Reaches both the agent pod (legacy exec flow: scheduled_task) and every
  # worker. The istio template paths are NOT here: they only
  # matter to the containers worker, which gets them from the variables above
  # with paths inside its own image.
  extra_envs = {
    CLUSTER_NAME       = module.eks.eks_cluster_name
    NAMESPACE          = "nullplatform-tools"
    DNS_TYPE           = var.dns_type
    DOMAIN             = ""
    USE_ACCOUNT_SLUG   = ""
    IMAGE_PULL_SECRETS = ""
  }

  # Repositories cloned for the legacy exec flow.
  agent_repo = [
    "https://github.com/nullplatform/scopes.git#v1.15.1",
    "https://github.com/nullplatform/services-postgresql-k-8-s.git#proposal/align-with-services-s-3",
    "https://github.com/nullplatform/services-dynamo-db.git#v0.2.0",
    "https://github.com/nullplatform/parameters-provider.git#v0.3.0"
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


# Parameter Store / Secrets Manager IAM roles.

module "parameter_store_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-parameter-store/specs/requirements?ref=v0.3.0"

  iam_role = var.iam_role
}

module "secrets_manager_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-secrets-manager/specs/requirements?ref=v0.3.0"

  iam_role = var.secrets_manager_iam_role
}
