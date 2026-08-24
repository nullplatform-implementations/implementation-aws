###############################################################################
# VPC
###############################################################################
module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v6.7.2"

  organization = "nullplatform"
  account      = var.name_prefix
  vpc          = var.vpc
}

###############################################################################
# EKS
###############################################################################
module "eks" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v6.7.2"

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # 2 nodos alcanzan: istiod sin HA, un agente, y los pods de la app de demo.
  node_group_min_size     = 2
  node_group_desired_size = 2
}

###############################################################################
# Route53 DNS + delegacion en la zona padre
###############################################################################
module "dns" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v6.7.2"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

# El modulo dns crea las zonas pero NO la delegacion. Sin este registro NS en la zona padre el
# subdominio de la demo no resuelve desde internet y la URL no es clickeable.
resource "aws_route53_record" "delegation" {
  zone_id = var.parent_public_zone_id
  name    = local.domain_name
  type    = "NS"
  ttl     = 300
  # El output se llama `nameservers` y es un STRING con los NS unidos por "\n", no una lista.
  records = split("\n", module.dns.nameservers)
}

module "external_dns_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/external_dns?ref=v6.7.2"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

module "cert_manager_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/cert_manager?ref=v6.7.2"

  hosted_zone_public_id               = module.dns.public_zone_id
  hosted_zone_private_id              = module.dns.private_zone_id
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name
}

###############################################################################
# ALB Controller
###############################################################################
module "alb_controller" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/aws_load_balancer_controller?ref=v6.7.2"

  depends_on = [module.eks]

  cluster_name = module.eks.eks_cluster_name
  vpc_id       = module.vpc.vpc_id
}

module "alb_controller_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/aws_load_balancer_controller_iam?ref=v6.7.2"

  cluster_name                        = module.eks.eks_cluster_name
  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
}

# istiod sin HA: es una demo de un solo cluster, 2 replicas no agregan nada y compiten por los 2 nodos.
module "istio" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/istio?ref=v6.7.2"

  depends_on = [module.alb_controller]

  service_type    = "LoadBalancer"
  istiod_replicas = 1
}

module "external_dns_public" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v6.7.2"

  depends_on = [module.alb_controller]

  type              = "public"
  zone_type         = "public"
  dns_provider_name = "aws"
  domain_filters    = module.dns.public_zone_name
  zone_id_filter    = module.dns.public_zone_id
  policy            = "sync"
  sources           = ["crd", "gateway-httproute"]
  aws_region        = var.aws_region
  aws_iam_role_arn  = module.external_dns_iam.nullplatform_external_dns_role_arn
}

module "external_dns_private" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/external_dns?ref=v6.7.2"

  depends_on = [module.alb_controller, module.external_dns_public]

  type              = "private"
  zone_type         = "private"
  create_namespace  = false
  dns_provider_name = "aws"
  domain_filters    = module.dns.private_zone_name
  zone_id_filter    = module.dns.private_zone_id
  policy            = "sync"
  sources           = ["crd", "gateway-httproute"]
  aws_region        = var.aws_region
  aws_iam_role_arn  = module.external_dns_iam.nullplatform_external_dns_role_arn
}

module "cert_manager" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/commons/cert_manager?ref=v6.7.2"

  # cert_manager_config crea recursos en el namespace "gateways", que lo crea el chart de module.base.
  # Sin esta dependencia explicita corren en paralelo y cert_manager_config gana la carrera.
  depends_on = [module.alb_controller, module.base]

  cloud_provider      = "aws"
  aws_sa_arn          = module.cert_manager_iam.nullplatform_cert_manager_role_arn
  hosted_zone_name    = module.dns.public_zone_name
  private_domain_name = module.dns.private_zone_name
  account_slug        = var.name_prefix
  aws_region          = var.aws_region
}

module "security" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/security?ref=v6.7.2"

  depends_on = [module.eks]

  cluster_name               = module.eks.eks_cluster_name
  vpc_id                     = module.vpc.vpc_id
  health_check_rules_enabled = true
  gateway_internal_enabled   = true
  cluster_security_group_id  = module.eks.eks_cluster_primary_security_group_id
  gateway_port               = 443
}

###############################################################################
# Nullplatform Agent API Key + chart base (crea los gateways)
###############################################################################
module "agent_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.7.2"

  nrn  = var.nrn
  type = "agent"
}

module "base" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/base?ref=v6.7.2"

  np_api_key   = module.agent_api_key.api_key
  k8s_provider = "eks"

  gateway_enabled                       = true
  gateway_internal_enabled              = true
  gateway_public_aws_security_group_id  = module.security.public_gateway_security_group_id
  gateway_private_aws_security_group_id = module.security.private_gateway_security_group_id

  # Tope de 32 chars en el nombre de LB de AWS, y unico en la cuenta: el cluster compartido ya usa
  # k8s-np-aws-services-public / -int.
  gateway_public_aws_name   = "k8s-np-uala-demo-public"
  gateway_internal_aws_name = "k8s-np-uala-demo-int"

  # En un cluster nuevo estos dos NO se pueden omitir (default false ambos). El layer compartido no
  # los pasa porque ahi las CRDs ya estaban instaladas de antes; sin CRDs no existe el kind Gateway.
  gateway_api_enabled      = true
  gateway_api_crds_install = true

  metrics_server_enabled = true
}

###############################################################################
# Cognito - solo para satisfacer AUTH_TYPE=aws-cognito del Endpoint Exposer.
# Pool vacio: con aws-cognito el servicio no llama a la API de AWS, Istio valida
# el JWT contra el JWKS del pool directamente.
###############################################################################
resource "aws_cognito_user_pool" "demo" {
  name = "${var.name_prefix}-exposer"
}

###############################################################################
# IAM del agente + requirements del scope k8s
###############################################################################
module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v6.7.2"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name

  # "nullplatform-tools", NO "nullplatform": es el namespace donde el chart despliega el agente
  # (default de var.namespace del modulo nullplatform/agent). Este valor entra en el `sub` de la
  # trust policy IRSA (system:serviceaccount:<ns>:nullplatform-agent); con el namespace equivocado
  # el token nunca matchea y todo assume-role falla con AccessDenied en
  # sts:AssumeRoleWithWebIdentity -- reproducido 2026-08-24, rompia la creacion de cualquier scope.
  agent_namespace = "nullplatform-tools"

  assume_role_arns = [module.scope_requirements_k8s.permissions_role_arn]
}

module "scope_requirements_k8s" {
  source = "git::https://github.com/nullplatform/scopes.git//k8s/specs/requirements/aws?ref=beta"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

###############################################################################
# Agente de nullplatform, con las envs del Endpoint Exposer
###############################################################################
module "agent" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/agent?ref=v6.7.2"

  depends_on = [module.base]

  api_key          = module.agent_api_key.api_key
  cluster_name     = module.eks.eks_cluster_name
  nrn              = var.nrn
  tags_selectors   = var.tags_selectors
  cloud_provider   = "aws"
  dns_type         = "external_dns"
  aws_iam_role_arn = module.agent_iam.nullplatform_agent_role_arn

  # Mismo default que declara infrastructure/aws/variables.tf del layer compartido.
  image_tag = "aws-0.7.0"

  # INGRESS_TYPE=istio por si solo NO alcanza: el workflow initial.yaml del scope k8s lee
  # INGRESS_TEMPLATE de la env var INITIAL_INGRESS_PATH (default "" en el modulo agent), y sin
  # esto cae al template ALB clasico -- reproducido 2026-08-24 (creo un objeto "ingress.networking.k8s.io"
  # en vez de una HTTPRoute). Mismos valores que usa el layer compartido (que si corre sobre Istio).
  service_template        = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/service.yaml.tpl"
  initial_ingress_path    = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/initial-httproute.yaml.tpl"
  blue_green_ingress_path = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/blue-green-httproute.yaml.tpl"

  agent_repos_scope = "https://github.com/nullplatform/scopes.git#beta"
  # NO se puede pinear a un tag ("v0.2.3"): el git manager del agente (supervisor/gitmanager) usa
  # plumbing.NewBranchReferenceName en clone/pull/reset, siempre resuelve "refs/heads/<ref>" y nunca
  # tags. services-endpoint-exposer usa release-please y no tiene branch de release, solo tags.
  # Verificado 2026-08-21: main y v0.2.3 apuntan al mismo commit (1afc8e3), asi que no hay drift.
  agent_repos_extra = [
    "https://github.com/nullplatform/services-endpoint-exposer.git#main"
  ]

  extra_envs = {
    INGRESS_TYPE = "istio"
    AUTH_TYPE    = "aws-cognito"
    # El sufijo sale de service.dimensions.environment con
    # tr '[:lower:]' '[:upper:]' | tr '-' '_', asi que "development" -> "DEVELOPMENT".
    COGNITO_USER_POOL_ARN_DEVELOPMENT = aws_cognito_user_pool.demo.arn
  }
}

###############################################################################
# ECR + usuario de CI para la app de demo
#
# El binding de ECR del cluster compartido no sirve: su rol de pull confia en el
# OIDC provider de ese cluster especifico. La demo necesita el suyo.
###############################################################################
module "ci_build_workflow_user" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ci-build-workflow-user?ref=v6.7.2"

  cluster_name = module.eks.eks_cluster_name
}

module "ecr_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ecr?ref=v6.7.2"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
}

###############################################################################
# AuthorizationPolicy permisiva sobre el gateway publico -- SOLO PARA LA DEMO.
#
# El Endpoint Exposer se llama "HTTP Route Access Control" y la authz es su razon de ser:
# build_allow_policies genera una AuthorizationPolicy ALLOW por cada ruta, y el template le
# mete un `when` con el claim request.auth.claims[cognito:groups] apenas `groups` tiene algo
# -- que es siempre, porque el schema del spec obliga minItems=1. No hay modo "publico".
#
# En Istio las policies ALLOW se UNEN: un request pasa si matchea al menos una. Esta policy
# permisiva (sin `when`, todos los paths) hace que las restrictivas del Exposer queden como
# no-op y los endpoints sean publicos, sin Cognito ni login.
#
# Para un entorno real esto NO va: ahi se configura el user pool de verdad y se deja que las
# policies del Exposer hagan su trabajo.
###############################################################################
resource "kubernetes_manifest" "demo_allow_all" {
  depends_on = [module.base]

  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "demo-allow-all-public"
      namespace = "gateways"
    }
    spec = {
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = "gateway-public"
        }
      }
      action = "ALLOW"
      rules  = [{}]
    }
  }
}
