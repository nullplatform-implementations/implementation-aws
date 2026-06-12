################################################################################
# Outputs - Nullplatform
#
# Specs are exposed as maps keyed by catalog slug.
# Because the comprehensions iterate over the module.* for_each instances, only
# ENABLED scopes/services appear — disabling one in var.scope_definitions /
# var.service_definitions removes it from the map (the output never breaks on a
# missing key, unlike per-entry outputs with literal indexes). Each entry also
# carries the catalog metadata (repository_org/name, service_path) so consumers
# can derive paths/URLs from a single ${org}/${name} if they want to.
################################################################################

output "scope_definitions" {
  description = "Enabled scope definitions keyed by catalog slug (id, slug, provider_specification_slug + catalog metadata)."
  value = {
    for k, m in module.scope_definitions : k => {
      id                          = m.service_specification_id
      slug                        = m.service_slug
      provider_specification_slug = try(m.provider_specification_slug, "")
      repository_org              = local.scope_definitions_enabled[k].repository_org
      repository_name             = local.scope_definitions_enabled[k].repository_name
      service_path                = local.scope_definitions_enabled[k].service_path
    }
  }
}

output "service_definitions" {
  description = "Enabled service definitions keyed by catalog slug (id, slug + catalog metadata)."
  value = {
    for k, m in module.service_definitions : k => {
      id              = m.service_specification_id
      slug            = m.service_specification_slug
      repository_org  = local.service_definitions_enabled[k].repository_org
      repository_name = local.service_definitions_enabled[k].repository_name
      service_path    = local.service_definitions_enabled[k].service_path
    }
  }
}
