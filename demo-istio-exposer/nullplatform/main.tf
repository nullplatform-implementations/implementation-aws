resource "nullplatform_namespace" "demo" {
  name       = "Uala Demo"
  account_id = var.account_id
}

# Scope Containers dedicado: el canal le cuelga el override del Exposer sin tocar el compartido.
# Branch "beta" porque la que referencia el catalogo compartido ya no existe en nullplatform/scopes.
module "scope_definition_containers" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v6.7.2"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_spec_name          = "Containers Demo Istio"
  service_spec_description   = "Docker containers on pods - cluster de la demo de Istio"
  service_path               = "k8s"
  create_scope_configuration = false

  # Solo pinear la branch: el default apunta a raw.githubusercontent.com, y github.com devuelve HTML.
  repository_service_spec_branch     = "beta"
  repository_scope_template_branch   = "beta"
  repository_action_templates_branch = "beta"

  # Default del modulo con un solo fix: "kill-instance" en singular, como esta en el repo.
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

# service_name tiene que ser el nombre canonico del repo, no uno mas lindo: el slug se deriva del
# name y el override hardcodea SERVICE_SPECIFICATION_SLUG=http-route-access-control. Con otro
# nombre, sync_exposer no encuentra el spec y delete-deployment reintenta en loop.
# Branch "main" y no el tag v0.2.3 por la limitacion del git manager (mismo commit igual).
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

  # Explicitos o hay drift en cada plan, y el PATCH resultante devuelve 404.
  settings = jsonencode({})
  tags     = jsonencode({})
}

# La api key que auto-provisiona la app nunca re-expone su valor en texto plano, asi que se crea
# una propia con el mismo rol para poder ponerla en el secret de GitHub.
# custom_grants y no custom_role_slugs: ese camino trunca la nrn a "organization:account" y una
# nrn de aplicacion se pierde en silencio.
module "ci_api_key" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v6.7.2"

  type        = "custom"
  custom_name = "ci-uala-demo-api-manual"
  custom_grants = [{
    nrn       = nullplatform_application.demo.nrn
    role_slug = "organization:machine:ci"
  }]
}

# La INSTANCIA del Exposer se crea por API/CLI, no aca: nullplatform_service tipa `attributes`
# como map(string), y este spec exige que `routes` sea un array de objetos. Con jsonencode el
# provider lo manda como string y la API devuelve 400 "routes/0 must be object".
# El resto del setup (spec, canal con el override, Cognito, DNS, provider config) si queda en TF.
