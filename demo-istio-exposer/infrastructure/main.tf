module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/vpc?ref=v6.7.2"

  organization = "nullplatform"
  account      = var.name_prefix
  vpc          = var.vpc
}

module "eks" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eks?ref=v6.7.2"

  name                         = local.cluster_name
  aws_vpc_vpc_id               = module.vpc.vpc_id
  aws_subnets_private_ids      = module.vpc.private_subnets
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # 3 nodos: con 2 el pod nuevo del blue/green queda sin schedulear.
  node_group_min_size     = 3
  node_group_desired_size = 3
}

module "dns" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/dns?ref=v6.7.2"

  depends_on = [module.vpc]

  vpc_id      = module.vpc.vpc_id
  domain_name = local.domain_name
}

# El modulo dns crea las zonas pero no la delegacion: sin este NS el subdominio no resuelve.
resource "aws_route53_record" "delegation" {
  zone_id = var.parent_public_zone_id
  name    = local.domain_name
  type    = "NS"
  ttl     = 300
  # `nameservers` es un string separado por "\n", no una lista.
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

# istiod sin HA: un solo cluster, la segunda replica solo compite por nodos.
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

  # cert_manager_config necesita el namespace que crea module.base; sin esto corren en paralelo.
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

  # Nombre de LB: tope de 32 chars y unico por cuenta.
  gateway_public_aws_name   = "k8s-np-uala-demo-public"
  gateway_internal_aws_name = "k8s-np-uala-demo-int"

  # Cluster nuevo: sin estas CRDs no existe el kind Gateway (ambos defaultean a false).
  gateway_api_enabled      = true
  gateway_api_crds_install = true

  metrics_server_enabled = true
}

# Solo para satisfacer AUTH_TYPE=aws-cognito del Exposer. Pool vacio: Istio valida contra el JWKS.
resource "aws_cognito_user_pool" "demo" {
  name = "${var.name_prefix}-exposer"
}

module "agent_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v6.7.2"

  aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
  cluster_name                        = module.eks.eks_cluster_name

  # "nullplatform-tools", NO "nullplatform": va en el `sub` del IRSA; con otro valor falla todo assume-role.
  agent_namespace = "nullplatform-tools"

  assume_role_arns = [module.scope_requirements_k8s.permissions_role_arn]
}

module "scope_requirements_k8s" {
  source = "git::https://github.com/nullplatform/scopes.git//k8s/specs/requirements/aws?ref=beta"

  cluster_name   = module.eks.eks_cluster_name
  agent_role_arn = local.agent_role_arn
}

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

  image_tag = "aws-0.7.0"

  # INGRESS_TYPE=istio no alcanza: sin estos paths se crea un Ingress de ALB, no una HTTPRoute.
  service_template        = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/service.yaml.tpl"
  initial_ingress_path    = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/initial-httproute.yaml.tpl"
  blue_green_ingress_path = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/blue-green-httproute.yaml.tpl"

  agent_repos_scope = "https://github.com/nullplatform/scopes.git#beta"
  # No se puede pinear a un tag: el git manager solo resuelve refs/heads/*. main == v0.2.3.
  agent_repos_extra = [
    "https://github.com/nullplatform/services-endpoint-exposer.git#main"
  ]

  extra_envs = {
    INGRESS_TYPE = "istio"
    AUTH_TYPE    = "aws-cognito"
    # El sufijo sale de service.dimensions.environment en UPPER_SNAKE.
    COGNITO_USER_POOL_ARN_DEVELOPMENT = aws_cognito_user_pool.demo.arn
  }
}

# ECR propio: el rol de pull del binding compartido confia en el OIDC provider de su cluster.
module "ci_build_workflow_user" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ci-build-workflow-user?ref=v6.7.2"

  cluster_name = module.eks.eks_cluster_name
}

module "ecr_iam" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/ecr?ref=v6.7.2"

  cluster_name              = module.eks.eks_cluster_name
  build_workflow_group_name = module.ci_build_workflow_user.group_name
}

# ALLOW sin `when` SOLO PARA LA DEMO: abre var.demo_public_routes sin token. Las ALLOW de Istio se
# unen y lo no matcheado da 403, lo que ademas cierra el catch-all del scope. No va en un entorno real.
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
      rules = [for r in var.demo_public_routes : {
        to = [{
          operation = {
            hosts   = r.hosts
            methods = r.methods
            paths   = r.paths
          }
        }]
      }]
    }
  }
}
