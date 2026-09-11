# =============================================================================
# Code Repository (GitHub)
# =============================================================================
module "code_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/code_repository?ref=v7.8.0"

  git_provider           = "github"
  nrn                    = var.nrn
  github_organization    = var.github_organization
  github_installation_id = var.github_installation_id
}

# =============================================================================
# Asset Repository (ECR)
# =============================================================================
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v7.8.0"

  nrn                              = var.nrn
  application_role_arn             = local.ecr_application_role_arn
  build_workflow_access_key_id     = local.ecr_build_workflow_access_key_id
  build_workflow_access_key_secret = local.ecr_build_workflow_access_key_secret
}

# =============================================================================
# Asset Repository (S3 - Lambda/bundle assets)
# =============================================================================
module "asset_s3" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/s3?ref=v7.8.0"

  nrn         = var.nrn
  bucket_name = "lambda-files-aws-services"
}

# =============================================================================
# Cloud Provider (AWS)
# =============================================================================
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v7.8.0"

  nrn                    = var.nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

# Assumable role ARNs keyed by selector, so each scope resolves its own role
# from the provider instead of an env var on the agent. ARNs come from
# infrastructure/aws via remote state.
module "identity_access_control" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/identity-access-control?ref=v7.8.0"

  nrn = var.nrn

  # type defaults to "aws-iam-configuration"
  attributes = {
    iam_role_arns = {
      arns = [
        { selector = "lambda", arn = local.lambda_assume_role_arn },
        { selector = "containers", arn = local.k8s_assume_role_arn },
        { selector = "static-files", arn = local.static_files_assume_role_arn },
        { selector = "parameter_store", arn = local.parameter_store_assume_role_arn },
        { selector = "secret_manager", arn = local.secret_manager_assume_role_arn },
        { selector = "s3", arn = local.s3_assume_role_arn },
        { selector = "dynamodb", arn = local.dynamodb_assume_role_arn },
        { selector = "rds-postgres-server", arn = local.rds_server_assume_role_arn },
        { selector = "rds-postgres-db", arn = local.rds_db_assume_role_arn }
      ]
    }
  }
}

# Notification API keys: one per entry in the catalog, keyed by scope/service slug.
module "notification_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v7.8.0"
  for_each = local.notification_api_keys_catalog

  type               = each.value.type
  nrn                = var.nrn
  specification_slug = each.value.specification_slug
}

# Scope channels: one per catalog entry; api_key wires by each.key.
module "scope_channel_associations" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v7.8.0"
  for_each = local.scope_channel_associations_catalog

  nrn                                    = var.nrn
  api_key                                = module.notification_api_keys[each.key].api_key
  tags_selectors                         = var.tags_selectors
  description                            = each.value.description
  scope_specification_id                 = each.value.scope_specification_id
  scope_specification_slug               = each.value.scope_specification_slug
  service_path                           = each.value.service_path
  repo_path                              = each.value.repo_path
  repository_notification_channel        = each.value.repository_notification_channel
  repository_notification_channel_branch = each.value.repository_notification_channel_branch

  # Workflow overrides (e.g. scopes-networking for the Lambda scope). Default
  # off for scopes that don't set them in the catalog.
  enabled_override       = try(each.value.enabled_override, false)
  override_repo_path     = try(each.value.override_repo_path, "")
  overrides_service_path = try(each.value.overrides_service_path, "")

  # package-exec: the agent runs the scope from its package worker image
  # instead of the clone above. Off unless the catalog entry enables it.
  worker_orchestrator = try(each.value.worker_orchestrator, false)
  package_slug        = try(each.value.package_slug, "")
}

# Service channels: one per catalog entry. Channels marked worker_orchestrator
# run the package image; the rest are resolved from the agent's clone at
# <base_clone_path>/<repo>/<service_path>/entrypoint/entrypoint.
module "service_channel_associations" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v7.8.0"
  for_each = local.service_channel_associations_catalog

  nrn                          = var.nrn
  api_key                      = module.notification_api_keys[each.key].api_key
  tags_selectors               = var.tags_selectors
  description                  = each.value.description
  service_specification_slug   = each.value.service_specification_slug
  repository_service_spec_repo = each.value.repository_service_spec_repo
  service_path                 = each.value.service_path

  # Clone root of the nonroot agent image (uid 1001).
  base_clone_path = "/home/agent/.np"

  # package-exec: the agent runs the service from its package worker image
  # instead of the clone above. Off unless the catalog entry enables it.
  worker_orchestrator = try(each.value.worker_orchestrator, false)
  package_slug        = try(each.value.package_slug, "")
}

module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/vpc?ref=v7.8.0"

  nrn                 = var.nrn
  vpc_id              = local.vpc_id
  vpc_security_groups = local.vpc_security_groups_ids
  vpc_subnets         = local.vpc_subnets_ids

  # The Lambda scope reads these listeners to attach its target groups. Public
  # and private point at the same (public) ALB until an internal one exists.
  load_balancer = {
    public = {
      arn          = local.lambda_alb_arn
      listener_arn = local.lambda_alb_listener_arn
    }
    private = {
      arn          = local.lambda_alb_arn
      listener_arn = local.lambda_alb_listener_arn
    }
  }
}


# =============================================================================
# Monitoring (Prometheus)
# =============================================================================
module "monitoring_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/metrics?ref=v7.8.0"

  nrn = var.nrn
}



# Parameter Store, served by the agent. The provider spec is fetched from the
# parameters-provider repo, not from a local template.

# Provider specification (replaces nullplatform_provider_specification.this).
module "parameter_store_spec" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition?ref=v7.8.0"

  nrn                                      = var.nrn
  np_api_key                               = var.np_api_key
  extra_visible_to_nrns                    = var.extra_visible_to_nrns
  template_path                            = var.template_path
  repository_parameter_storage_spec_branch = var.repository_parameter_storage_spec_branch
  repository_parameter_storage_spec        = var.repository_parameter_storage_spec
}

# Provider instances (replaces module.scope_configuration on scope_configuration v4.5.1).
module "parameter_store_configuration" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_configuration?ref=v7.8.0"

  for_each = var.parameter_store_instances

  nrn        = each.value.nrn
  type       = "aws-parameter-store"
  dimensions = each.value.dimensions
  applies_to = each.value.attributes.sensibility.applies_to
  kms_key_id = each.value.attributes.setup.kms_key_id
  tier       = each.value.attributes.setup.tier

  depends_on = [module.parameter_store_spec]
}

# Agent API keys (replaces nullplatform_api_key.this). type="agent" applies the
# same grants: controlplane:agent, developer, ops, secops, secrets-reader.
module "parameter_store_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v7.8.0"
  for_each = { for key, instance in var.parameter_store_instances : key => instance if instance.enable_notification_channel }

  type               = "agent"
  nrn                = each.value.nrn
  specification_slug = "parameter_storage"
}

# Agent notification channels (replaces nullplatform_notification_channel.from_template).
module "parameter_store_channels" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition_agent_association?ref=v7.8.0"
  for_each = { for key, instance in var.parameter_store_instances : key => instance if instance.enable_notification_channel }

  nrn            = each.value.nrn
  api_key        = module.parameter_store_api_keys[each.key].api_key
  description    = each.value.description
  tags_selectors = each.value.tags_selectors

  depends_on = [module.parameter_store_spec]
}

# Secrets Manager, same modules as Parameter Store; only the remote spec
# template differs (no `tier` in the schema).

# Provider specification.
module "secrets_manager_spec" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition?ref=v7.8.0"

  nrn                                      = var.nrn
  np_api_key                               = var.np_api_key
  extra_visible_to_nrns                    = var.extra_visible_to_nrns
  template_path                            = var.secrets_manager_template_path
  repository_parameter_storage_spec_branch = var.repository_parameter_storage_spec_branch
  repository_parameter_storage_spec        = var.repository_parameter_storage_spec
}

# Provider instances.
module "secrets_manager_configuration" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_configuration?ref=v7.8.0"

  for_each = var.secrets_manager_instances

  nrn        = each.value.nrn
  type       = "aws-secrets-manager"
  dimensions = each.value.dimensions
  applies_to = each.value.attributes.sensibility.applies_to
  kms_key_id = each.value.attributes.setup.kms_key_id

  depends_on = [module.secrets_manager_spec]
}

# Agent API keys (type="agent"). specification_slug stays "parameter_storage".
module "secrets_manager_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v7.8.0"
  for_each = { for key, instance in var.secrets_manager_instances : key => instance if instance.enable_notification_channel }

  type               = "agent"
  nrn                = each.value.nrn
  specification_slug = "parameter_storage"
}

# Agent notification channels.
module "secrets_manager_channels" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition_agent_association?ref=v7.8.0"
  for_each = { for key, instance in var.secrets_manager_instances : key => instance if instance.enable_notification_channel }

  nrn            = each.value.nrn
  api_key        = module.secrets_manager_api_keys[each.key].api_key
  description    = each.value.description
  tags_selectors = each.value.tags_selectors

  depends_on = [module.secrets_manager_spec]
}


# Static scope configuration; the provider slug comes from the nullplatform
# layer via remote state.
module "scope_configuration_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=v7.8.0"

  nrn  = var.nrn
  type = "static-files"
  dimensions = {
    environment = "development"
  }

  cloud_provider            = "aws"
  aws_region                = "us-east-1"
  aws_state_bucket          = "tf-state-0269fb2df210b43c"
  aws_hosted_public_zone_id = "Z08274782HV2M61TD1NFE"
  aws_lambda_associations = [
    {
      event_type   = "viewer-response"
      function_arn = "arn:aws:lambda:us-east-1:235494813897:function:edge-test-header:1"
    }
  ]
}

# =============================================================================
# Scope Configuration - Lambda
# =============================================================================
module "scope_configuration_lambda" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=v7.8.0"

  nrn  = var.nrn
  type = "aws-lambda"
  dimensions = {
    environment = "development"
  }

  lambda_tofu_state_bucket = "nullplatform-lambda-tfstate-aws-services"
  # Used verbatim by scopes-lambda when set (no architecture suffix appended).
  lambda_placeholder_image_uri = "235494813897.dkr.ecr.us-east-1.amazonaws.com/aws-lambda/nullplatform-lambda-placeholder:latest-amd64"
}


