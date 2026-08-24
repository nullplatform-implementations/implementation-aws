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
#
# service_name = "HTTP Route Access Control" (el nombre canonico del repo, NO un nombre mas
# lindo): container-scope-override/values.yaml hardcodea
# SERVICE_SPECIFICATION_SLUG=http-route-access-control, y el slug se auto-deriva del name. Con
# "Endpoint Exposer" el slug queda "endpoint-exposer" y sync_exposer nunca encuentra el spec
# -- reproducido 2026-08-24: "Could not find service specification with slug
# 'http-route-access-control'", delete-deployment reintentando en loop.
module "service_definition_endpoint_exposer" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v6.7.2"

  nrn               = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services-endpoint-exposer"
  repository_branch = "main"
  service_path      = ""
  service_name      = "HTTP Route Access Control"
  available_links   = ["connect"]
  available_actions = []
}

resource "nullplatform_application" "demo" {
  name           = "Uala Demo API"
  namespace_id   = nullplatform_namespace.demo.id
  repository_url = "https://github.com/nullplatform-implementations/aws-service-uala-demo-api"

  # Explicitos para que no haya drift entre state y API: sin esto tofu detecta un cambio en cada
  # plan (removing settings/tags "{}"") y el PATCH resultante devuelve 404 -- reproducido dos veces.
  settings = jsonencode({})
  tags     = jsonencode({})
}

# La app trae auto-provisionada una api key "ci-uala-demo-..." con rol organization:machine:ci,
# scopeada a su propia NRN -- pero nullplatform nunca re-expone el valor en texto plano despues
# de crearla (solo masked_api_key). Se crea una propia con el mismo rol/scope para poder leer el
# valor real y ponerlo en el secret de GitHub.
#
# custom_grants, NO custom_role_slugs + nrn: el modulo trunca var.nrn a "organization:account" via
# local.nrn_without_namespace para el camino de custom_role_slugs (pensado para grants de cuenta
# como agent/scope_notification/service_notification), asi que un nrn de aplicacion se pierde en
# silencio. custom_grants es el unico camino que respeta la NRN completa que se le pasa.
module "ci_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.7.2"

  type        = "custom"
  custom_name = "ci-uala-demo-api-manual"
  custom_grants = [{
    nrn       = nullplatform_application.demo.nrn
    role_slug = "organization:machine:ci"
  }]
}

###############################################################################
# La INSTANCIA del servicio Endpoint Exposer (la que crea la HTTPRoute +
# AuthorizationPolicy + RequestAuthentication sobre el scope de la demo) NO se crea aca.
#
# El recurso nullplatform_service del provider define `attributes` como Map(String) a nivel de
# Go schema (resource_service.go: Elem: &schema.Schema{Type: schema.TypeString}), y lo manda
# tal cual -- como STRING -- al campo `attributes` del body JSON (service.go:
# Attributes map[string]interface{}, json.Marshal directo, sin reinterpretar valores). El schema
# de este spec exige que `routes` sea un array real de objetos; con jsonencode(...) el provider
# manda "routes" como *string* JSON-encodeado, y la API devuelve 400
# "body/attributes/routes/0 must be object" -- reproducido 2026-08-24. No hay forma de expresar
# un atributo array/objeto anidado con este resource tal como esta hoy.
#
# Mismo patron que el scope (Task 10): la instancia se crea por API/CLI (np service create),
# no por Terraform. Lo que si queda 100% en Terraform es todo el setup (este archivo): el spec,
# el canal con el override, la dimension, Cognito, el dominio/DNS y el provider config de EKS.
###############################################################################
