resource "nullplatform_namespace" "demo" {
  name       = "Uala Demo"
  account_id = var.account_id
}

# Scope Containers dedicado: el canal de nullplatform-bindings le cuelga el override del Exposer,
# asi el scope Containers del cluster compartido queda intacto.
#
# Branch "beta": "feat/scope-definition-available-actions" (la que usa el catalogo actual de
# origin/main del layer compartido) no existe mas en el repo nullplatform/scopes (404, verificado
# 2026-08-21) -- ese catalogo referencia una branch borrada, probablemente nunca se re-aplico tras
# el commit que la cambio. "beta" existe y es la misma que ya clona el agente de este stack sin error.
module "scope_definition_containers" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v6.7.2"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_spec_name          = "Containers Demo Istio"
  service_spec_description   = "Docker containers on pods - cluster de la demo de Istio"
  service_path               = "k8s"
  create_scope_configuration = false

  # NO overridear repository_service_spec/scope_template/action_templates: el default del modulo
  # ya es "https://raw.githubusercontent.com/nullplatform/scopes/refs/heads" (el dominio CDN de
  # contenido crudo). Pasar "https://github.com/nullplatform/scopes" ahi rompe el fetch (github.com
  # devuelve HTML, no el .tpl) -- solo hace falta pinear la branch.
  repository_service_spec_branch     = "beta"
  repository_scope_template_branch   = "beta"
  repository_action_templates_branch = "beta"

  # El default del modulo trae "kill-instances" (plural); en k8s/specs/actions de la branch beta
  # el archivo real es "kill-instance.json.tpl" (singular) -- verificado 2026-08-21 via GitHub API.
  # Se copia el default del modulo con ese unico nombre corregido.
  action_spec_names = [
    "create-scope",
    "delete-scope",
    "start-initial",
    "start-blue-green",
    "finalize-blue-green",
    "rollback-deployment",
    "delete-deployment",
    "switch-traffic",
    "set-desired-instance-count",
    "pause-autoscaling",
    "resume-autoscaling",
    "restart-pods",
    "kill-instance",
    "diagnose-deployment",
    "diagnose-scope"
  ]
}

# Endpoint Exposer. El spec del repo se llama "HTTP Route Access Control" (slug
# http-route-access-control) -- service_name lo renombra para que en la UI diga algo reconocible.
# Branch "main": no se puede pinear al tag v0.2.3 (el git manager del agente solo resuelve
# refs/heads/*, ver comentario en infrastructure/aws/main.tf). main == v0.2.3 al mismo commit.
module "service_definition_endpoint_exposer" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v6.7.2"

  nrn               = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services-endpoint-exposer"
  repository_branch = "main"
  service_path      = ""
  service_name      = "Endpoint Exposer"
  available_links   = ["connect"]
  available_actions = []
}

resource "nullplatform_application" "demo" {
  name           = "Uala Demo API"
  namespace_id   = nullplatform_namespace.demo.id
  repository_url = "https://github.com/nullplatform-implementations/aws-service-uala-demo-api"
}
