# =============================================================================
# Scope definitions
#
# One module instance per enabled entry in local.scope_definitions_enabled.
# Add/remove a scope by editing the catalog in locals.tf; toggle or pin a
# version per environment from terraform.tfvars (var.scope_definitions).
# =============================================================================
module "scope_definitions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v4.3.0"
  for_each = local.scope_definitions_enabled

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_spec_name          = each.value.service_spec_name
  service_spec_description   = each.value.service_spec_description
  service_path               = each.value.service_path
  action_spec_names          = each.value.action_spec_names
  create_scope_configuration = each.value.create_scope_configuration

  repository_service_spec            = coalesce(each.value.repository_service_spec, each.value.repository_url)
  repository_service_spec_branch     = coalesce(each.value.repository_service_spec_version, each.value.version)
  repository_scope_template          = coalesce(each.value.repository_scope_template, each.value.repository_url)
  repository_scope_template_branch   = coalesce(each.value.repository_scope_template_version, each.value.version)
  repository_action_templates        = coalesce(each.value.repository_action_templates, each.value.repository_url)
  repository_action_templates_branch = coalesce(each.value.repository_action_templates_version, each.value.version)
}

# =============================================================================
# Service definitions
#
# One module instance per enabled entry in local.service_definitions_enabled.
# =============================================================================
module "service_definitions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v4.3.0"
  for_each = local.service_definitions_enabled

  nrn               = var.nrn
  repository_org    = each.value.repository_org
  repository_name   = each.value.repository_name
  repository_branch = each.value.repository_branch
  service_path      = each.value.service_path
  service_name      = each.value.service_name
  available_links   = each.value.available_links
  available_actions = each.value.available_actions
}

# =============================================================================
# Scope Configuration - Static Scope
# =============================================================================
module "scope_configuration_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=v4.3.0"

  nrn                         = var.nrn
  np_api_key                  = var.np_api_key
  provider_specification_slug = module.scope_definitions["static_files"].provider_specification_slug
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
# Dimensions
#
# One module instance per enabled entry in local.dimensions_enabled. Add/remove
# a dimension by editing the catalog in locals.tf; toggle or override values per
# environment from terraform.tfvars (var.dimensions).
# =============================================================================
module "dimensions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimension?ref=v4.3.0"
  for_each = local.dimensions_enabled

  nrn    = var.nrn
  name   = each.value.name
  order  = each.value.order
  values = each.value.values
}

# Extra value for the Environment dimension, scoped to a specific namespace.
module "dimension_value_environment_produccion_only" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimension_value?ref=v4.3.0"

  dimension_id = module.dimensions["environment"].id
  name         = "produccion-only"
  nrn          = "organization=1698562351:account=1372325109:namespace=1901730273"
}
