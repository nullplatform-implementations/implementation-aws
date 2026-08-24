###############################################################################
# Notification API Keys
###############################################################################
module "api_key_scope_containers" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.7.2"

  nrn                = var.nrn
  type               = "scope_notification"
  specification_slug = local.scope_specification_slug
}

module "api_key_service_exposer" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.7.2"

  nrn                = var.nrn
  type               = "service_notification"
  specification_slug = local.service_specification_slug_exposer
}

###############################################################################
# Canal del scope Containers, CON el override del Endpoint Exposer
#
# Los tres inputs de override inyectan el step sync_exposer en los workflows de deploy
# (initial, blue_green, switch_traffic, finalize, rollback, delete): sin eso el HTTPRoute del
# Exposer sigue apuntando al Service del deployment viejo despues de un blue/green.
# UNA sola association por scope spec -- dos canales con los mismos filters corren el
# entrypoint dos veces (ver README de services-endpoint-exposer).
###############################################################################
module "scope_channel_containers" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition_agent_association?ref=v6.7.2"

  nrn                      = var.nrn
  api_key                  = module.api_key_scope_containers.api_key
  tags_selectors           = var.tags_selectors
  description              = "Containers Demo Istio scope agent channel"
  scope_specification_id   = local.scope_specification_id
  scope_specification_slug = local.scope_specification_slug
  service_path             = "k8s"
  repo_path                = "/root/.np/nullplatform/scopes"

  # Mismo branch "beta" que agent_repos_scope y el registro del spec (Task 5 y 6): agente,
  # templates de registro y template del canal, todo consistente.
  repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes/refs/heads"
  repository_notification_channel_branch = "beta"

  enabled_override       = true
  override_repo_path     = "/root/.np/nullplatform/services-endpoint-exposer"
  overrides_service_path = "/container-scope-override"
}

###############################################################################
# Canal del servicio Endpoint Exposer
###############################################################################
module "service_channel_exposer" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v6.7.2"

  nrn                          = var.nrn
  api_key                      = module.api_key_service_exposer.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_exposer
  repository_service_spec_repo = "nullplatform/services-endpoint-exposer"
  service_path                 = ""
}

###############################################################################
# Asset Repository (ECR) -- necesario para que np asset push funcione
###############################################################################
# nrn acotada al namespace: la cuenta ya tiene un asset_repository (ECR) registrado por el layer
# compartido a nivel account, y este provider_config es unico por NRN+type -- usar var.nrn (account)
# choca 400 "The provider already exists". Namespace-scoped coexiste y gana por especificidad.
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v6.7.2"

  nrn                              = local.namespace_nrn
  application_role_arn             = local.ecr_application_role_arn
  build_workflow_access_key_id     = local.ecr_build_workflow_access_key_id
  build_workflow_access_key_secret = local.ecr_build_workflow_access_key_secret
}

###############################################################################
# Cloud provider (AWS) -- domain_name + hosted zones para ESTE namespace.
#
# nrn acotada al namespace (no a la account): sin esto el scope hereda el
# aws-configuration de la cuenta compartida, cuyo domain_name (aws-services.nullapps.io)
# apunta al cluster viejo, no al de la demo.
###############################################################################
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v6.7.2"

  nrn                    = local.namespace_nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

###############################################################################
# EKS provider config -- que cluster usan los scopes de ESTE namespace.
#
# Sin esto un scope k8s del namespace de la demo hereda el "eks-configuration" de la cuenta
# compartida (clusterId=aws-services-cluster) -- verificado 2026-08-24 al crear el scope de
# prueba: su runtime_configuration resuelto apuntaba al cluster VIEJO, no al de la demo.
###############################################################################
module "eks_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/container_orchestration/eks?ref=v6.7.2"

  nrn          = local.namespace_nrn
  cluster_name = local.cluster_name
}
