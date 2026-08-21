output "namespace_id" { value = nullplatform_namespace.demo.id }

output "scope_definitions" {
  value = {
    containers = {
      id                          = module.scope_definition_containers.service_specification_id
      slug                        = module.scope_definition_containers.service_slug
      provider_specification_slug = try(module.scope_definition_containers.provider_specification_slug, "")
    }
  }
}

output "service_definitions" {
  value = {
    endpoint_exposer = {
      id   = module.service_definition_endpoint_exposer.service_specification_id
      slug = module.service_definition_endpoint_exposer.service_specification_slug
    }
  }
}
