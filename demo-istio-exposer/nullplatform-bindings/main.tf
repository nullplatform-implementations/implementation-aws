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
