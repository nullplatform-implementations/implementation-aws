# Scope definitions: one module instance per enabled catalog entry (locals.tf).
# Each one also publishes a package revision pinning its spec, actions and
# artifacts; re-applying the same package_version with the same content is a no-op.
module "scope_definitions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v7.8.0"
  for_each = local.scope_definitions_enabled

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_spec_name          = each.value.service_spec_name
  service_spec_description   = each.value.service_spec_description
  service_path               = each.value.service_path
  create_scope_configuration = each.value.create_scope_configuration

  repository_service_spec            = coalesce(each.value.repository_service_spec, each.value.repository_url)
  repository_service_spec_branch     = coalesce(each.value.repository_service_spec_version, each.value.version)
  repository_scope_template          = coalesce(each.value.repository_scope_template, each.value.repository_url)
  repository_scope_template_branch   = coalesce(each.value.repository_scope_template_version, each.value.version)
  repository_action_templates        = coalesce(each.value.repository_action_templates, each.value.repository_url)
  repository_action_templates_branch = coalesce(each.value.repository_action_templates_version, each.value.version)


  package = {
    version   = each.value.package_version
    artifacts = each.value.package_artifacts
    default   = true
  }
}

# Service definitions: one module instance per enabled catalog entry.
module "service_definitions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v7.8.0"
  for_each = local.service_definitions_enabled

  nrn                 = var.nrn
  repository_org      = each.value.repository_org
  repository_name     = each.value.repository_name
  repository_branch   = each.value.repository_branch
  repository_ref_type = each.value.repository_ref_type
  service_path        = each.value.service_path
  service_name        = each.value.service_name
  available_links     = each.value.available_links
  available_actions   = each.value.available_actions

  package = {
    version   = each.value.package_version
    artifacts = each.value.package_artifacts
    default   = true
  }
}

# Dimensions: one module instance per enabled catalog entry.
module "dimensions" {
  source   = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimension?ref=v7.8.0"
  for_each = local.dimensions_enabled

  nrn    = var.nrn
  name   = each.value.name
  order  = each.value.order
  values = each.value.values
}

# Extra value for the Environment dimension, scoped to a specific namespace.
module "dimension_value_environment_produccion_only" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimension_value?ref=v7.8.0"

  dimension_id = module.dimensions["environment"].id
  name         = "produccion-only"
  nrn          = "organization=1698562351:account=1372325109:namespace=1901730273"
}
