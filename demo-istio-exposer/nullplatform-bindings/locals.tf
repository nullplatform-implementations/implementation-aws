locals {
  scope_specs   = data.terraform_remote_state.nullplatform.outputs.scope_definitions
  service_specs = data.terraform_remote_state.nullplatform.outputs.service_definitions

  scope_specification_id             = local.scope_specs["containers"].id
  scope_specification_slug           = local.scope_specs["containers"].slug
  service_specification_slug_exposer = local.service_specs["endpoint_exposer"].slug

  namespace_id = data.terraform_remote_state.nullplatform.outputs.namespace_id

  # NRN acotada al namespace de la demo: el provider_config de dominio/DNS se resuelve por
  # especificidad de NRN, y sin esto el scope heredaria el "aws-configuration" de la cuenta
  # compartida (domain_name = aws-services.nullapps.io, que apunta al OTRO cluster).
  namespace_nrn = "${var.nrn}:namespace=${local.namespace_id}"

  domain_name     = data.terraform_remote_state.infrastructure.outputs.domain_name
  public_zone_id  = data.terraform_remote_state.infrastructure.outputs.public_zone_id
  private_zone_id = data.terraform_remote_state.infrastructure.outputs.private_zone_id
  cluster_name    = data.terraform_remote_state.infrastructure.outputs.cluster_name

  ecr_application_role_arn             = data.terraform_remote_state.infrastructure.outputs.ecr_application_role_arn
  ecr_build_workflow_access_key_id     = data.terraform_remote_state.infrastructure.outputs.ecr_build_workflow_access_key_id
  ecr_build_workflow_access_key_secret = data.terraform_remote_state.infrastructure.outputs.ecr_build_workflow_access_key_secret
}
