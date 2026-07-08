# =============================================================================
# Code Repository (GitHub)
# =============================================================================
module "code_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/code_repository?ref=v5.3.1"

  git_provider           = "github"
  nrn                    = var.nrn
  github_organization    = var.github_organization
  github_installation_id = var.github_installation_id
}

# =============================================================================
# Asset Repository (ECR)
# =============================================================================
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v5.3.1"

  nrn                              = var.nrn
  application_role_arn             = local.ecr_application_role_arn
  build_workflow_access_key_id     = local.ecr_build_workflow_access_key_id
  build_workflow_access_key_secret = local.ecr_build_workflow_access_key_secret
}

# =============================================================================
# Asset Repository (S3 - Lambda/bundle assets)
# =============================================================================
module "asset_s3" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/s3?ref=v5.3.1"

  nrn         = var.nrn
  bucket_name = "lambda-files-aws-services"
}

# =============================================================================
# Cloud Provider (AWS)
# =============================================================================
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v5.3.1"

  nrn                    = var.nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

# =============================================================================
# Identity & Access Control (AWS IAM provider)
#
# Publishes assumable role ARNs keyed by selector. The Lambda scope resolves
# its role here (selector "lambda") via the provider — replacing the
# ASSUME_ROLE_ARN_DEFAULT env var on the agent. The ARN comes from the Lambda
# assume-role created in infrastructure/aws (read via remote state).
# =============================================================================
module "identity_access_control" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/identity-access-control?ref=v5.3.1"

  nrn = var.nrn

  # type defaults to "aws-iam-configuration"
  attributes = {
    iam_role_arns = {
      arns = [
        { selector = "lambda", arn = local.lambda_assume_role_arn },
        { selector = "k8s", arn = local.k8s_assume_role_arn },
        { selector = "static-files", arn = local.static_files_assume_role_arn },
        { selector = "parameter_store", arn = local.parameter_store_assume_role_arn },
        { selector = "secret_manager", arn = local.secret_manager_assume_role_arn },
        { selector = "s3", arn = local.s3_assume_role_arn },
        { selector = "rds-postgres-server", arn = local.rds_server_assume_role_arn },
        { selector = "rds-postgres-db", arn = local.rds_db_assume_role_arn }
      ]
    }
  }
}

# =============================================================================
# Notification API Keys
#
# One module instance per entry in local.notification_api_keys_catalog
# (scope_notification and service_notification keys, keyed by scope/service slug).
# =============================================================================
module "notification_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v5.3.1"
  for_each = local.notification_api_keys_catalog

  type               = each.value.type
  nrn                = var.nrn
  specification_slug = each.value.specification_slug
}

# =============================================================================
# Channel Associations - Scope to Agent
#
# One module instance per entry in local.scope_channel_associations_catalog.
# api_key wires by each.key to module.notification_api_keys.
# =============================================================================
module "scope_channel_associations" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v5.3.1"
  for_each = local.scope_channel_associations_catalog

  nrn                                    = var.nrn
  api_key                                = module.notification_api_keys[each.key].api_key
  tags_selectors                         = var.tags_selectors
  scope_specification_id                 = each.value.scope_specification_id
  scope_specification_slug               = each.value.scope_specification_slug
  service_path                           = each.value.service_path
  repo_path                              = each.value.repo_path
  repository_notification_channel        = each.value.repository_notification_channel
  repository_notification_channel_branch = each.value.repository_notification_channel_branch
}

# =============================================================================
# Channel Associations - Service to Agent
#
# One module instance per entry in local.service_channel_associations_catalog.
# The agent resolves the entrypoint from:
#   <base_clone_path>/<repository_service_spec_repo>/<service_path>/entrypoint/entrypoint
# =============================================================================
module "service_channel_associations" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v5.3.1"
  for_each = local.service_channel_associations_catalog

  nrn                          = var.nrn
  api_key                      = module.notification_api_keys[each.key].api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = each.value.service_specification_slug
  repository_service_spec_repo = each.value.repository_service_spec_repo
  service_path                 = each.value.service_path
}

module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/vpc?ref=v5.3.1"

  nrn                 = var.nrn
  vpc_id              = local.vpc_id
  vpc_security_groups = local.vpc_security_groups_ids
  vpc_subnets         = local.vpc_subnets_ids
}


# =============================================================================
# Monitoring (Prometheus)
# =============================================================================
module "monitoring_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/metrics?ref=v5.3.1"

  nrn = var.nrn
}



# =============================================================================
# PARAMETER STORE VIA AGENT
#
# Migrated from inline resources to the dedicated parameter-storage modules
# (tofu-modules v6.2.0 / api_key v6.1.0). The provider spec is now fetched
# remotely from the parameters-provider repo (data.http + gomplate) instead of
# the local .tpl.
# =============================================================================

# Provider specification (replaces nullplatform_provider_specification.this).
module "parameter_store_spec" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition?ref=v6.2.2"

  nrn                                      = var.nrn
  np_api_key                               = var.np_api_key
  extra_visible_to_nrns                    = var.extra_visible_to_nrns
  template_path                            = var.template_path
  repository_parameter_storage_spec_branch = var.repository_parameter_storage_spec_branch
  repository_parameter_storage_spec        = var.repository_parameter_storage_spec
}

# Provider instances (replaces module.scope_configuration on scope_configuration v4.5.1).
module "parameter_store_configuration" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_configuration?ref=v6.2.2"

  for_each = var.parameter_store_instances

  nrn                         = each.value.nrn
  np_api_key                  = var.np_api_key
  provider_specification_slug = module.parameter_store_spec.slug
  dimensions                  = each.value.dimensions
  attributes                  = each.value.attributes

  depends_on = [module.parameter_store_spec]
}

# Agent API keys (replaces nullplatform_api_key.this). type="agent" applies the
# same grants: controlplane:agent, developer, ops, secops, secrets-reader.
module "parameter_store_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.1.0"
  for_each = { for key, instance in var.parameter_store_instances : key => instance if instance.enable_notification_channel }

  type               = "agent"
  nrn                = each.value.nrn
  specification_slug = "parameter_storage"
}

# Agent notification channels (replaces nullplatform_notification_channel.from_template).
module "parameter_store_channels" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition_agent_association?ref=v6.2.2"
  for_each = { for key, instance in var.parameter_store_instances : key => instance if instance.enable_notification_channel }

  nrn            = each.value.nrn
  api_key        = module.parameter_store_api_keys[each.key].api_key
  tags_selectors = each.value.tags_selectors

  depends_on = [module.parameter_store_spec]
}

# =============================================================================
# SECRETS MANAGER VIA AGENT
#
# Same parameter-storage modules as Parameter Store (the modules are generic).
# The provider differs only in the remote spec template (slug aws-secrets-manager,
# schema without `tier`), fetched from the same parameters-provider repo.
# =============================================================================

# Provider specification.
module "secrets_manager_spec" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition?ref=v6.2.2"

  nrn                                      = var.nrn
  np_api_key                               = var.np_api_key
  extra_visible_to_nrns                    = var.extra_visible_to_nrns
  template_path                            = var.secrets_manager_template_path
  repository_parameter_storage_spec_branch = var.repository_parameter_storage_spec_branch
  repository_parameter_storage_spec        = var.repository_parameter_storage_spec
}

# Provider instances.
module "secrets_manager_configuration" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_configuration?ref=v6.2.2"

  for_each = var.secrets_manager_instances

  nrn                         = each.value.nrn
  np_api_key                  = var.np_api_key
  provider_specification_slug = module.secrets_manager_spec.slug
  dimensions                  = each.value.dimensions
  attributes                  = each.value.attributes

  depends_on = [module.secrets_manager_spec]
}

# Agent API keys (type="agent"). specification_slug stays "parameter_storage".
module "secrets_manager_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.1.0"
  for_each = { for key, instance in var.secrets_manager_instances : key => instance if instance.enable_notification_channel }

  type               = "agent"
  nrn                = each.value.nrn
  specification_slug = "parameter_storage"
}

# Agent notification channels.
module "secrets_manager_channels" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition_agent_association?ref=v6.2.2"
  for_each = { for key, instance in var.secrets_manager_instances : key => instance if instance.enable_notification_channel }

  nrn            = each.value.nrn
  api_key        = module.secrets_manager_api_keys[each.key].api_key
  tags_selectors = each.value.tags_selectors

  depends_on = [module.secrets_manager_spec]
}


# =============================================================================
# Scope Configuration - Static Scope
#
# Moved here from nullplatform/. provider_specification_slug comes from the
# nullplatform remote_state (already read as local.scope_specs).
# =============================================================================
module "scope_configuration_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=v5.3.1"

  nrn                         = var.nrn
  np_api_key                  = var.np_api_key
  provider_specification_slug = local.scope_specs["static_files"].provider_specification_slug
  dimensions = {
    environment = "development"
  }
  attributes = {
    cloud_provider = "aws"
    provider = {
      aws_region       = "us-east-1"
      aws_state_bucket = "tf-state-0269fb2df210b43c"
    }
    distribution = {
      aws_distribution = "cloudfront"
      lambda_associations = [
        {
          event_type   = "viewer-response"
          function_arn = "arn:aws:lambda:us-east-1:235494813897:function:edge-test-header:1"
        }
      ]
    }
    network = {
      aws_network               = "route53"
      aws_hosted_public_zone_id = "Z08274782HV2M61TD1NFE"
    }
    security = {
      aws_security     = "none"
      aws_web_acl_name = ""
    }
  }
}

# =============================================================================
# Scope Configuration - Lambda
# =============================================================================
module "scope_configuration_lambda" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=v5.3.1"

  nrn                         = var.nrn
  np_api_key                  = var.np_api_key
  provider_specification_slug = local.scope_specs["aws_lambda"].provider_specification_slug
  dimensions = {
    environment = "development"
  }

  attributes = {
    state = {
      tofu_state_bucket = "nullplatform-lambda-tfstate-aws-services"
    }
    deployment = {
      placeholder_image_uri = "235494813897.dkr.ecr.us-east-1.amazonaws.com/aws-lambda/nullplatform-lambda-placeholder:latest-amd64"
    }
  }
}

