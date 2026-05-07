# =============================================================================
# Code Repository (GitHub)
# =============================================================================
module "code_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/code_repository?ref=v2.2.1"

  git_provider           = "github"
  nrn                    = var.nrn
  github_organization    = var.github_organization
  github_installation_id = var.github_installation_id
}

# =============================================================================
# Asset Repository (ECR)
# =============================================================================
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v2.2.1"

  nrn          = var.nrn
  cluster_name = local.cluster_name
}

# =============================================================================
# Cloud Provider (AWS)
# =============================================================================
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v2.2.1"

  nrn                    = var.nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

# =============================================================================
# API Keys - Scope Notifications
# =============================================================================
module "scope_notification_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "scope_notification"
  nrn                = var.nrn
  specification_slug = local.scope_specification_slug
}

module "scope_notification_api_key_scheduled_task" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "scope_notification"
  nrn                = var.nrn
  specification_slug = local.scope_specification_slug_scheduled_task
}

module "scope_notification_api_key_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "scope_notification"
  nrn                = var.nrn
  specification_slug = local.scope_specification_slug_static_scope
}


module "service_notification_api_key_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_rds_server
}


module "service_notification_api_key_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_rds_db
}

module "service_notification_api_key_aws_s3_bucket" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_aws_s3_bucket
}

module "service_notification_api_key_postgres_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v2.2.1"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_postgres_db
}



# =============================================================================
# Channel Associations - Scope to Agent
# =============================================================================
module "scope_definition_channel_association" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v2.2.1"

  nrn                      = var.nrn
  api_key                  = module.scope_notification_api_key.api_key
  scope_specification_id   = local.scope_specification_id
  scope_specification_slug = local.scope_specification_slug
  tags_selectors           = var.tags_selectors
}

module "scope_definition_channel_association_scheduled_task" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v2.2.1"

  nrn                      = var.nrn
  api_key                  = module.scope_notification_api_key_scheduled_task.api_key
  scope_specification_id   = local.scope_specification_id_scheduled_task
  scope_specification_slug = local.scope_specification_slug_scheduled_task
  tags_selectors           = var.tags_selectors
  service_path             = "scheduled_task"
}

module "scope_definition_channel_association_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v2.2.1"

  nrn                      = var.nrn
  api_key                  = module.scope_notification_api_key_static_scope.api_key
  scope_specification_id   = local.scope_specification_id_static_scope
  scope_specification_slug = local.scope_specification_slug_static_scope
  tags_selectors           = var.tags_selectors
  service_path             = "static-files"
  repo_path                = "/root/.np/nullplatform/scopes-static-files"

  repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_notification_channel_branch = "main"
}


module "service_definition_channel_association_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v2.2.1"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_rds_server.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_rds_server
  repository_service_spec_repo = "nullplatform/services"
  service_path                 = "databases/rds-postgres-server"
}

module "service_definition_channel_association_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v2.2.1"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_rds_db.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_rds_db
  repository_service_spec_repo = "nullplatform/services"
  service_path                 = "databases/rds-postgres-db"
}


# =============================================================================
# Service Definition - AWS S3 Bucket
# The agent executes the entrypoint from:
#   <base_clone_path>/<repository_service_spec_repo>/<service_path>/entrypoint/entrypoint
# = /root/.np/nullplatform/services-s-3/aws-s3-bucket/entrypoint/entrypoint
# =============================================================================
module "service_definition_channel_association_aws_s3_bucket" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v2.2.1"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_aws_s3_bucket.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_aws_s3_bucket
  repository_service_spec_repo = "nullplatform/services-s-3"
  service_path                 = "aws-s3-bucket"
}

# =============================================================================
# Service Definition - Postgres DB (Kubernetes)
# Entrypoint resolved from:
#   /root/.np/nullplatform/services-postgresql-k-8-s/postgres-db/entrypoint/entrypoint
# The branch to clone is handled by the agent itself (driven by the
# service_definition registered in the nullplatform state, currently pinned
# to `proposal/align-with-services-s-3`).
# =============================================================================
module "service_definition_channel_association_postgres_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v2.2.1"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_postgres_db.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_postgres_db
  repository_service_spec_repo = "nullplatform/services-postgresql-k-8-s"
  service_path                 = "postgres-db"
}

module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/vpc?ref=v2.2.1"

  nrn                 = var.nrn
  vpc_id              = local.vpc_id
  vpc_security_groups = local.vpc_security_groups_ids
  vpc_subnets         = local.vpc_subnets_ids
}




# =============================================================================
# Monitoring (Prometheus)
# =============================================================================
module "monitoring_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/metrics?ref=v2.2.1"

  nrn        = var.nrn
}
