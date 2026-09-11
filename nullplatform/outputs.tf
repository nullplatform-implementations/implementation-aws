# Specs exposed as maps keyed by catalog slug, built from the module for_each
# instances, so a disabled scope/service simply drops out of the map.

output "scope_definitions" {
  description = "Enabled scope definitions keyed by catalog slug (id, slug, provider_specification_slug + catalog metadata + package)."
  value = {
    for k, m in module.scope_definitions : k => {
      id                          = m.service_specification_id
      slug                        = m.service_slug
      provider_specification_slug = try(m.provider_specification_slug, "")
      repository_org              = local.scope_definitions_enabled[k].repository_org
      repository_name             = local.scope_definitions_enabled[k].repository_name
      service_path                = local.scope_definitions_enabled[k].service_path
      version                     = local.scope_definitions_enabled[k].version
      package = {
        id              = m.package_id
        default_version = m.package_default_version
      }
    }
  }
}

output "service_definitions" {
  description = "Enabled service definitions keyed by catalog slug (id, slug + catalog metadata + package)."
  value = {
    for k, m in module.service_definitions : k => {
      id              = m.service_specification_id
      slug            = m.service_specification_slug
      repository_org  = local.service_definitions_enabled[k].repository_org
      repository_name = local.service_definitions_enabled[k].repository_name
      service_path    = local.service_definitions_enabled[k].service_path
      version         = local.service_definitions_enabled[k].repository_branch
      package = {
        id              = m.package_id
        default_version = m.package_default_version
      }
    }
  }
}
