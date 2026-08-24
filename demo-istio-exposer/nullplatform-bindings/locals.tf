locals {
  scope_specs   = data.terraform_remote_state.nullplatform.outputs.scope_definitions
  service_specs = data.terraform_remote_state.nullplatform.outputs.service_definitions

  scope_specification_id             = local.scope_specs["containers"].id
  scope_specification_slug           = local.scope_specs["containers"].slug
  service_specification_slug_exposer = local.service_specs["endpoint_exposer"].slug
}
