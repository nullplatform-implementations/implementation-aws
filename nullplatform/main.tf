# =============================================================================
# Scope Definition - Containers
# =============================================================================
module "scope_definition" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.39.0"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path
  service_spec_name        = var.service_spec_name
  service_spec_description = var.service_spec_description
  action_spec_names        = var.action_spec_names
}

# =============================================================================
# Scope Definition - Scheduled Tasks
# =============================================================================
module "scope_definition_scheduled_task" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.39.0"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path_scheduled_task
  service_spec_name        = var.service_spec_name_scheduled_task
  service_spec_description = var.service_spec_description_scheduled_task
  action_spec_names        = var.action_spec_names_scheduled_task
}


# =============================================================================
# Scope Definition - Static Scope
# =============================================================================
module "scope_definition_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.39.0"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path_static_scope
  service_spec_name        = var.service_spec_name_static_scope
  service_spec_description = var.service_spec_description_static_scope
  action_spec_names        = var.action_spec_names_static_scope

  repository_service_spec      = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_service_spec_branch     = "no-testing-submodule"
  repository_scope_template    = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_scope_template_branch   = "no-testing-submodule"
  repository_action_templates  = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_action_templates_branch = "no-testing-submodule"
}


# =============================================================================
# Dimensions
# =============================================================================
module "dimensions" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimensions?ref=v1.39.0"

  nrn          = var.nrn
  np_api_key   = var.np_api_key
  environments = var.environments
}
