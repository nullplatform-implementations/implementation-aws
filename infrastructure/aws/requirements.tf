###############################################################################
# Scope, service and parameter provider requirements
#
# Cloud-side prerequisites each scope/service/parameter provider needs before the
# agent can run its actions: IAM roles the agent assumes, plus whatever the
# module provisions (the Lambda ALB, KMS policies, ...). Each ref must match the
# version the same entry pins in nullplatform/locals.tf.
###############################################################################

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

module "parameter_store_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-parameter-store/specs/requirements?ref=v0.3.0"

  iam_role = var.iam_role
}

module "secrets_manager_requirements" {
  source = "git::https://github.com/nullplatform/parameters-provider.git//parameters/providers/aws-secrets-manager/specs/requirements?ref=v0.3.0"

  iam_role = var.secrets_manager_iam_role
}
