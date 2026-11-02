###############################################################################
# VPC
###############################################################################
module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v9.9.0"

  organization = var.organization
  account      = var.account
  vpc          = var.vpc
}

# EKS. The module carries its own kubernetes provider, so this block cannot
# take depends_on/count/for_each; the vpc references below already order it.
module "eks" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v9.9.0"

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  aws_profile                  = var.aws_profile

  # Bump node count from 2 to 3 to give the cluster overhead for node drains
  # (istiod HA + rolling updates). Current 2-node cluster is saturated.
  node_group_min_size     = 3
  node_group_desired_size = 3
  # t3.large (8Gi) instead of t3.medium (4Gi): istiod and the agent's workers
  # request 2Gi each, and with t3.medium three of four nodes sat above 55% of
  # requested memory, leaving no room for rollouts (a logs-controller pod went
  # Pending during the istio 1.30.7 upgrade).
  instance_types = "t3.large"

  # EKS upgrades one minor at a time: bump kubernetes_version, the AMI release
  # and the addons together, apply, verify, then repeat for the next minor.
  # AMI:    aws ssm get-parameter --name /aws/service/eks/optimized-ami/<k8s>/amazon-linux-2023/x86_64/standard/recommended/release_version
  # Addons: aws eks describe-addon-versions --kubernetes-version <k8s> --addon-name <addon>
  # Pinned so neither follows whatever AWS publishes between plans.
  kubernetes_version             = "1.35"
  ami_release_version            = "1.35.9-20261031"
  use_latest_ami_release_version = false
  addon_versions = {
    aws-ebs-csi-driver     = "v1.67.2-eksbuild.1"
    coredns                = "v1.14.7-eksbuild.22"
    eks-pod-identity-agent = "v1.4.1-eksbuild.3"
    kube-proxy             = "v1.35.3-eksbuild.62"
    vpc-cni                = "v1.23.2-eksbuild.8"
  }
}

###############################################################################
# Route53 DNS
###############################################################################
module "dns" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v9.9.0"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

###############################################################################
# ALB Controller
###############################################################################
module "alb_controller" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/aws_load_balancer_controller?ref=v9.9.0"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id

  # Chart 3.x carries the controller's own version (v2.13.4 shipped as chart
  # 1.13.4). Helm does not upgrade CRDs: before bumping, apply the chart's CRDs
  #   kubectl apply --server-side -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=<eks-charts tag>"
  # with the eks-charts tag whose Chart.yaml matches this version (v0.0.249 for 3.6.2).
  aws_load_balancer_controller_version = "3.6.2"
}

###############################################################################
# Istio
###############################################################################
module "istio" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/istio?ref=v9.9.0"

  # Istio only supports in-place upgrades one minor at a time: 1.27.1 -> 1.28.10
  # -> 1.29.7 -> 1.30.4 (the module default), one apply per hop.
  istio_base_version = "1.30.7"
  istiod_version     = "1.30.7"
  istiod_replicas    = 2

  depends_on = [module.alb_controller]
}

###############################################################################
# Prometheus
###############################################################################
module "prometheus" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/prometheus?ref=v9.9.0"

  # Pinned per tofu-modules VERSIONS.md.
  prometheus_version = "29.40.0"
}

###############################################################################
# IAM Roles
###############################################################################
module "external_dns_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/external_dns?ref=v9.9.0"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "cert_manager_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/cert_manager?ref=v9.9.0"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "alb_controller_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/aws_load_balancer_controller_iam?ref=v9.9.0"

  cluster_name                        = module.eks.eks_cluster_name
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
}

module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v9.9.0"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  agent_namespace                     = var.agent_namespace
  cluster_name                        = module.eks.eks_cluster_name

  assume_role_arns = [
    module.scope_requirements_lambda.permissions_role_arn,
    module.scope_requirements_k8s.permissions_role_arn,
    module.scope_requirements_static_files.permissions_role_arn,
    module.scope_requirements_mobile_store.permissions_role_arn,
    module.scope_requirements_voltmx_foundry_app.permissions_role_arn,
    module.service_requirements_s3.permissions_role_arn,
    module.service_requirements_dynamodb.permissions_role_arn,
    module.service_requirements_rds_server.permissions_role_arn,
    module.service_requirements_rds_db.permissions_role_arn,
    module.parameter_store_requirements.iam_role_arn,
    module.secrets_manager_requirements.iam_role_arn
  ]
}

# IAM role the CI assumes with its OIDC token to push images and assets (ECR,
# Lambda zips, mobile binaries), so no access key leaves AWS. Replaces the
# ci-build-workflow-user IAM user. The GitHub OIDC provider already exists in
# the account (create = false looks it up).
module "ci_build_workflow_role" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ci-build-workflow-role?ref=v9.9.0"

  cluster_name = module.eks.eks_cluster_name

  oidc_providers = {
    github = {
      url = "https://token.actions.githubusercontent.com"
      subjects = [
        "repo:${var.github_organization}/*",
        "repo:${var.github_organization}@${var.github_organization_id}/*",
      ]
    }
  }
}

module "ecr_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ecr?ref=v9.9.0"

  cluster_name             = module.eks.eks_cluster_name
  build_workflow_role_name = module.ci_build_workflow_role.role_name
}

module "s3_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/s3?ref=v9.9.0"

  cluster_name             = module.eks.eks_cluster_name
  build_workflow_role_name = module.ci_build_workflow_role.role_name
  bucket                   = "lambda-files-aws-services"
}

# Lets the CI build workflow identity publish mobile binaries (mobile-store scope POC).
module "s3_iam_mobile" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/s3?ref=v9.9.0"

  cluster_name             = "${module.eks.eks_cluster_name}-mobile"
  build_workflow_role_name = module.ci_build_workflow_role.role_name
  bucket                   = aws_s3_bucket.assets_mobile.bucket
}

###############################################################################
# External DNS
###############################################################################
module "external_dns_public" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v9.9.0"

  depends_on = [module.alb_controller]

  type                 = "public"
  zone_type            = "public"
  dns_provider_name    = var.dns_provider_name
  external_dns_version = "1.23.0"
  domain_filters       = module.dns.public_zone_name
  zone_id_filter       = module.dns.public_zone_id
  policy               = var.policy
  sources              = var.sources
  aws_region           = var.aws_region
  aws_iam_role_arn     = module.external_dns_iam.nullplatform_external_dns_role_arn
}

module "external_dns_private" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v9.9.0"

  depends_on = [module.alb_controller, module.external_dns_public]

  type                 = "private"
  zone_type            = "private"
  create_namespace     = false
  dns_provider_name    = var.dns_provider_name
  external_dns_version = "1.23.0"
  domain_filters       = module.dns.private_zone_name
  zone_id_filter       = module.dns.private_zone_id
  policy               = var.policy
  sources              = var.sources
  aws_region           = var.aws_region
  aws_iam_role_arn     = module.external_dns_iam.nullplatform_external_dns_role_arn
}

###############################################################################
# Cert Manager
###############################################################################
module "cert_manager" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/cert_manager?ref=v9.9.0"

  depends_on = [module.alb_controller]

  cloud_provider      = var.cloud_provider
  aws_sa_arn          = module.cert_manager_iam.nullplatform_cert_manager_role_arn
  hosted_zone_name    = module.dns.public_zone_name
  private_domain_name = module.dns.private_zone_name
  account_slug        = var.organization_slug
  aws_region          = var.aws_region

  # Pinned per tofu-modules VERSIONS.md.
  cert_manager_version = "v1.21.3"
}

###############################################################################
# Security
###############################################################################
module "security" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/security?ref=v9.9.0"

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
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v9.9.0"

  nrn  = var.nrn
  type = "agent"
}

###############################################################################
# Nullplatform Base
###############################################################################

# Owned here, not by the base chart: its template only renders this namespace
# when it does not exist, so an upgrade dropped it and Helm deleted the
# Gateways with it (2026-09-03).
resource "kubernetes_namespace" "gateways" {
  metadata {
    name   = "gateways"
    labels = { name = "gateways" }
  }
}

module "base" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/base?ref=v9.9.0"

  depends_on = [kubernetes_namespace.gateways]

  k8s_provider                          = var.k8s_provider
  gateway_public_aws_security_group_id  = module.security.public_gateway_security_group_id
  gateway_private_aws_security_group_id = module.security.private_gateway_security_group_id
  gateway_enabled                       = true
  gateway_internal_enabled              = true
  gateway_public_aws_name               = "k8s-np-aws-services-public"
  gateway_internal_aws_name             = "k8s-np-aws-services-int"

  metrics_server_enabled = true

  # Everything pinned: the chart to what is deployed, the images to the
  # versions VERSIONS.md documents (they were running :latest).
  nullplatform_base_helm_version = "2.44.7"
  logging_controller_image_tag   = "v1.7.0"

  # The chart's CRD job is a no-op once the CRDs exist (helm-charts#183).
  install_gateway_v2_crd = false
}

###############################################################################
# Nullplatform Agent
###############################################################################
module "agent" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/agent?ref=v9.9.0"

  depends_on = [module.base]

  api_key                         = module.agent_api_key.api_key
  tags_selectors                  = var.tags_selectors
  image_tag                       = var.image_tag
  nullplatform_agent_helm_version = var.agent_helm_version
  agent_traffic_manager_tag       = var.traffic_manager_tag
  cloud_provider                  = var.cloud_provider
  aws_iam_role_arn                = module.agent_iam.nullplatform_agent_role_arn
  dns_type                        = var.dns_type

  # Deploy through the Istio Gateway API templates the scopes/containers image
  # bakes in, instead of the k8s scope's default ALB Ingress ones.
  ingress_stack = "istio"

  # Run every package in its own worker pod. Off by default since v8.0.0: with
  # it off the module drops the whole worker block below (patches, registries,
  # idleTTL, security) and the packages fall back to running inside the agent.
  worker_orchestrator = true

  # The k8s scope defaults to asking every pod for an "ecr-secret" it never
  # creates, and the kubelet warns on each one. Images come from the node role
  # here, so no pull secret is needed. Drop this once scopes ships #256, which
  # turns the default off and makes the provider setting work.
  image_pull_secrets = jsonencode({ ENABLED = false })

  # Reap idle worker pods after 15m (the agent recreates them on demand).
  # security is plaintext ("insecure" before chart 3.1.0 renamed it): the agent
  # reaches its workers unencrypted, so any pod that can reach one runs commands
  # with the agent's IAM identity. Nothing currently narrows that — this
  # namespace has no NetworkPolicy — so the mitigations are "mtls" here or an
  # ingress policy on the worker pods.
  worker = {
    idleTTL  = "15m"
    security = "plaintext"

    # Concatenated with the module's default (public.ecr.aws/nullplatform/*).
    allowedRegistries = ["${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/scopes/*"]


    # The lambda image ships scopes-lambda alone, so an init container fetches
    # the ALB/Route53 steps from scopes-networking into a shared volume and
    # NP_OVERRIDES_PATH points the worker at them.
    patches = [
      {
        target = { package = "aws-lambda-agustin" }
        merge = {
          spec = {
            volumes = [{ name = "overrides", emptyDir = {} }]
            initContainers = [{
              name         = "fetch-overrides"
              image        = "public.ecr.aws/docker/library/alpine:3.20"
              command      = ["sh", "-c", "wget -qO- https://github.com/nullplatform/scopes-networking/archive/refs/tags/${var.scopes_networking_version}.tar.gz | tar -xzC /overrides --strip-components=1"]
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

  # Packages run as workers: they get the agent's ServiceAccount (IRSA) and the
  # chart's worker resources (2Gi memory limit from chart 3.4.0). These are
  # package slugs, not catalog keys.
  worker_orchestrated_packages = [
    "containers",
    "static-scope",
    "mobile-store",
    "voltmx-foundry-app",
    "aws-s3-bucket-agent-k8s",
    "rds-postgres-server-agustin-test",
    "rds-postgres-database-agustin-test",
    "aws-lambda-agustin",
    "scheduled-task",
    "aws-dynamodb-agustin-test",
    "postgres-db-k8s-agustin-test",
  ]

  # Both run the k8s scope code (scheduled-task is the k8s scope with the
  # scheduled_task overlay), so both workers get its env from the module.
  worker_k8s_packages = ["containers", "scheduled-task"]
  cluster_name        = module.eks.eks_cluster_name


  # Repositories cloned for the legacy exec flow.
  agent_repo = [
    "https://github.com/nullplatform/parameters-provider.git#v0.3.0"
  ]
}
