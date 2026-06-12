# =============================================================================
# Code Repository (GitHub)
# =============================================================================
module "code_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/code_repository?ref=v4.3.0"

  git_provider           = "github"
  nrn                    = var.nrn
  github_organization    = var.github_organization
  github_installation_id = var.github_installation_id
}

# =============================================================================
# Asset Repository (ECR)
# =============================================================================
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v4.3.0"

  nrn                              = var.nrn
  application_role_arn             = local.ecr_application_role_arn
  build_workflow_access_key_id     = local.ecr_build_workflow_access_key_id
  build_workflow_access_key_secret = local.ecr_build_workflow_access_key_secret
}

# =============================================================================
# Cloud Provider (AWS)
# =============================================================================
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v4.3.0"

  nrn                    = var.nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

# =============================================================================
# Notification API Keys
#
# One module instance per entry in local.notification_api_keys_catalog
# (scope_notification and service_notification keys, keyed by scope/service slug).
# =============================================================================
module "notification_api_keys" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v4.3.0"
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
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v4.3.0"
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
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v4.3.0"
  for_each = local.service_channel_associations_catalog

  nrn                          = var.nrn
  api_key                      = module.notification_api_keys[each.key].api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = each.value.service_specification_slug
  repository_service_spec_repo = each.value.repository_service_spec_repo
  service_path                 = each.value.service_path
}

module "vpc" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/vpc?ref=v4.3.0"

  nrn                 = var.nrn
  vpc_id              = local.vpc_id
  vpc_security_groups = local.vpc_security_groups_ids
  vpc_subnets         = local.vpc_subnets_ids
}


# =============================================================================
# Monitoring (Prometheus)
# =============================================================================
module "monitoring_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/metrics?ref=v4.3.0"

  nrn        = var.nrn
}
