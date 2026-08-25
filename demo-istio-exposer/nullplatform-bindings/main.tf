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

# Canal del scope, con el override del Exposer: los tres inputs de override inyectan el step
# sync_exposer en los workflows de deploy, sin el cual el HTTPRoute queda apuntando al Service
# viejo despues de un blue/green. UNA sola association por spec: dos canales con los mismos
# filters corren el entrypoint dos veces.
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

  # Mismo branch que el agente y el registro del spec.
  repository_notification_channel        = "https://raw.githubusercontent.com/nullplatform/scopes/refs/heads"
  repository_notification_channel_branch = "beta"

  enabled_override       = true
  override_repo_path     = "/root/.np/nullplatform/services-endpoint-exposer"
  overrides_service_path = "/container-scope-override"
}

module "service_channel_exposer" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v6.7.2"

  nrn                          = var.nrn
  api_key                      = module.api_key_service_exposer.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_exposer
  repository_service_spec_repo = "nullplatform/services-endpoint-exposer"
  service_path                 = ""
}

# nrn de namespace: el provider_config es unico por NRN+type y a nivel cuenta ya hay uno.
module "asset_repository" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/asset/ecr?ref=v6.7.2"

  nrn                              = local.namespace_nrn
  application_role_arn             = local.ecr_application_role_arn
  build_workflow_access_key_id     = local.ecr_build_workflow_access_key_id
  build_workflow_access_key_secret = local.ecr_build_workflow_access_key_secret
}

# Dominio y hosted zones de ESTE namespace: sin esto el scope hereda el aws-configuration de la
# cuenta, que apunta al otro cluster.
module "cloud_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/cloud/aws/cloud?ref=v6.7.2"

  nrn                    = local.namespace_nrn
  domain_name            = local.domain_name
  hosted_public_zone_id  = local.public_zone_id
  hosted_private_zone_id = local.private_zone_id
}

# Que cluster usan los scopes de este namespace: sin esto heredan el eks-configuration de la cuenta.
module "eks_provider" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/container_orchestration/eks?ref=v6.7.2"

  nrn          = local.namespace_nrn
  cluster_name = local.cluster_name
}

# Que rol asume el agente para los scopes de este namespace: sin esto intenta el del cluster
# compartido y create-scope falla con AccessDenied. El selector "containers" es el del scope k8s.
module "identity_access_control" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/identity-access-control?ref=v6.7.2"

  nrn = local.namespace_nrn

  attributes = {
    iam_role_arns = {
      arns = [
        {
          selector = "containers"
          arn      = local.k8s_assume_role_arn
        }
      ]
    }
  }
}
