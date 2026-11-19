# Specs exposed as maps keyed by catalog slug, built from the module for_each
# instances, so a disabled scope/service simply drops out of the map. Published
# entries (scope_definition / service_definition) and installed ones
# (scope_package_installation / package_installation) expose the same output
# names, so nullplatform-bindings reads one map with both.

locals {
  scopes_enabled   = merge(local.published_scopes_enabled, local.installed_scopes_enabled)
  services_enabled = merge(local.published_services_enabled, local.installed_services_enabled)
}

output "scope_definitions" {
  description = "Enabled scopes, published and installed, keyed by catalog slug (id, slug, provider_specification_slug + catalog metadata + package)."
  value = {
    for k, m in merge(module.scope_definitions, module.scope_installations) : k => {
      id                          = m.service_specification_id
      slug                        = m.service_slug
      provider_specification_slug = try(m.provider_specification_slug, "")
      repository_org              = local.scopes_enabled[k].repository_org
      repository_name             = local.scopes_enabled[k].repository_name
      service_path                = local.scopes_enabled[k].service_path
      version                     = local.scopes_enabled[k].version
      package = {
        id              = m.package_id
        default_version = m.package_default_version
      }
    }
  }
}

output "service_definitions" {
  description = "Enabled services, published and installed, keyed by catalog slug (id, slug + catalog metadata + package)."
  value = {
    for k, m in merge(module.service_definitions, module.service_installations) : k => {
      id              = m.service_specification_id
      slug            = m.service_specification_slug
      repository_org  = local.services_enabled[k].repository_org
      repository_name = local.services_enabled[k].repository_name
      service_path    = local.services_enabled[k].service_path
      version         = local.services_enabled[k].repository_branch
      package = {
        id              = m.package_id
        default_version = m.package_default_version
      }
    }
  }
}
