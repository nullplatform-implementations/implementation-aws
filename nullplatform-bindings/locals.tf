locals {
  # Infrastructure - variable overrides remote state
  public_zone_id  = var.public_zone_id != null ? var.public_zone_id : data.terraform_remote_state.infrastructure[0].outputs.public_zone_id
  private_zone_id = var.private_zone_id != null ? var.private_zone_id : data.terraform_remote_state.infrastructure[0].outputs.private_zone_id
  cluster_name    = var.cluster_name != null ? var.cluster_name : data.terraform_remote_state.infrastructure[0].outputs.cluster_name
  domain_name     = var.domain_name != null ? var.domain_name : data.terraform_remote_state.infrastructure[0].outputs.domain_name

  # Nullplatform specs — read from the remote state maps (keyed by catalog slug,
  # only enabled entries present). Mapped explicitly to the per-entry locals the
  # catalogs below already consume, so the catalogs stay untouched.
  scope_specs   = data.terraform_remote_state.nullplatform.outputs.scope_definitions
  service_specs = data.terraform_remote_state.nullplatform.outputs.service_definitions

  scope_specification_id                  = local.scope_specs["containers"].id
  scope_specification_slug                = local.scope_specs["containers"].slug
  scope_specification_id_scheduled_task   = local.scope_specs["scheduled_tasks"].id
  scope_specification_slug_scheduled_task = local.scope_specs["scheduled_tasks"].slug
  scope_specification_id_static_scope     = local.scope_specs["static_files"].id
  scope_specification_slug_static_scope   = local.scope_specs["static_files"].slug
  scope_specification_id_lambda           = local.scope_specs["aws_lambda"].id
  scope_specification_slug_lambda         = local.scope_specs["aws_lambda"].slug

  service_specification_slug_rds_server    = local.service_specs["rds_postgres_server"].slug
  service_specification_slug_rds_db        = local.service_specs["rds_postgres_db"].slug
  service_specification_slug_aws_s3_bucket = local.service_specs["aws_s3_bucket"].slug
  service_specification_slug_postgres_db   = local.service_specs["postgres_db_k8s"].slug

  vpc_id = data.terraform_remote_state.infrastructure[0].outputs.vpc_id
  vpc_subnets_ids = data.terraform_remote_state.infrastructure[0].outputs.vpc_subnets_ids
  vpc_security_groups_ids  = data.terraform_remote_state.infrastructure[0].outputs.vpc_security_groups_ids

  # ECR IAM (created by infrastructure/aws module "ecr_iam", consumed by asset_repository)
  ecr_application_role_arn             = data.terraform_remote_state.infrastructure[0].outputs.ecr_application_role_arn
  ecr_build_workflow_access_key_id     = data.terraform_remote_state.infrastructure[0].outputs.ecr_build_workflow_access_key_id
  ecr_build_workflow_access_key_secret = data.terraform_remote_state.infrastructure[0].outputs.ecr_build_workflow_access_key_secret

  ##############################################################################
  # Notification API keys catalog
  #
  # One nullplatform notification api_key per scope/service, keyed by slug.
  # 'type' selects scope vs service notification; 'specification_slug' is the
  # spec the key is scoped to (resolved from the nullplatform remote state).
  ##############################################################################
  notification_api_keys_catalog = {
    containers     = { type = "scope_notification", specification_slug = local.scope_specification_slug }
    scheduled_task = { type = "scope_notification", specification_slug = local.scope_specification_slug_scheduled_task }
    static_scope   = { type = "scope_notification", specification_slug = local.scope_specification_slug_static_scope }
    aws_lambda     = { type = "scope_notification", specification_slug = local.scope_specification_slug_lambda }
    rds_server     = { type = "service_notification", specification_slug = local.service_specification_slug_rds_server }
    rds_db         = { type = "service_notification", specification_slug = local.service_specification_slug_rds_db }
    aws_s3_bucket  = { type = "service_notification", specification_slug = local.service_specification_slug_aws_s3_bucket }
    postgres_db    = { type = "service_notification", specification_slug = local.service_specification_slug_postgres_db }
  }

  ##############################################################################
  # Scope channel associations catalog (scope_definition_agent_association)
  #
  # Optional fields (service_path, repo_path, repository_notification_channel*)
  # are null when the scope relies on the module defaults. Keys match
  # notification_api_keys_catalog so api_key wires by each.key.
  ##############################################################################
  scope_channel_associations_catalog = {
    containers = {
      scope_specification_id                 = local.scope_specification_id
      scope_specification_slug               = local.scope_specification_slug
      service_path                           = "k8s"
      repo_path                              = "/root/.np/nullplatform/scopes"
      repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes/refs/heads"
      repository_notification_channel_branch = "main"
    }
    scheduled_task = {
      scope_specification_id                 = local.scope_specification_id_scheduled_task
      scope_specification_slug               = local.scope_specification_slug_scheduled_task
      service_path                           = "scheduled_task"
      repo_path                              = "/root/.np/nullplatform/scopes"
      repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes/refs/heads"
      repository_notification_channel_branch = "main"
    }
    static_scope = {
      scope_specification_id                 = local.scope_specification_id_static_scope
      scope_specification_slug               = local.scope_specification_slug_static_scope
      service_path                           = "static-files"
      repo_path                              = "/root/.np/nullplatform/scopes-static-files"
      repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
      repository_notification_channel_branch = "main"
    }
    aws_lambda = {
      scope_specification_id                 = local.scope_specification_id_lambda
      scope_specification_slug               = local.scope_specification_slug_lambda
      service_path                           = "lambda"
      repo_path                              = "/root/.np/nullplatform/scopes-lambda"
      repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes-lambda/refs/heads"
      repository_notification_channel_branch = "feature/assume-role-support"
    }
  }

  ##############################################################################
  # Service channel associations catalog (service_definition_agent_association)
  ##############################################################################
  service_channel_associations_catalog = {
    rds_server = {
      service_specification_slug   = local.service_specification_slug_rds_server
      repository_service_spec_repo = "nullplatform/services"
      service_path                 = "databases/rds-postgres-server"
    }
    rds_db = {
      service_specification_slug   = local.service_specification_slug_rds_db
      repository_service_spec_repo = "nullplatform/services"
      service_path                 = "databases/rds-postgres-db"
    }
    aws_s3_bucket = {
      service_specification_slug   = local.service_specification_slug_aws_s3_bucket
      repository_service_spec_repo = "nullplatform/services-s-3"
      service_path                 = "aws-s3-bucket"
    }
    postgres_db = {
      service_specification_slug   = local.service_specification_slug_postgres_db
      repository_service_spec_repo = "nullplatform/services-postgresql-k-8-s"
      service_path                 = "postgres-db"
    }
  }





}
