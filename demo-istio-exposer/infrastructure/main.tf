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
