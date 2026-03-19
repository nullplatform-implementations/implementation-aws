################################################################################
# Outputs - Nullplatform
################################################################################

output "service_specification_id" {
  description = "ID of the service specification created by scope_definition"
  value       = module.scope_definition.service_specification_id
}

output "service_slug" {
  description = "Slug of the service created by scope_definition"
  value       = module.scope_definition.service_slug
}

output "scope_specification_id" {
  description = "Scope specification ID (from service_specification)"
  value       = module.scope_definition.service_specification_id
}

output "scope_specification_slug" {
  description = "Scope specification slug (from service_slug)"
  value       = module.scope_definition.service_slug
}

output "service_specification_id_scheduled_task" {
  description = "ID of the service specification created by scope_definition for scheduled task"
  value       = module.scope_definition_scheduled_task.service_specification_id
}

output "service_slug_scheduled_task" {
  description = "Slug of the service created by scope_definition for scheduled task"
  value       = module.scope_definition_scheduled_task.service_slug
}


output "scope_specification_id_scheduled_task" {
  description = "Scope specification ID for scheduled tasks"
  value       = module.scope_definition_scheduled_task.service_specification_id
}

output "scope_specification_slug_scheduled_task" {
  description = "Scope specification slug for scheduled tasks"
  value       = module.scope_definition_scheduled_task.service_slug
}


output "scope_specification_id_static_scope" {
  description = "Scope specification ID for static scope"
  value       = module.scope_definition_static_scope.service_specification_id
}

output "scope_specification_slug_static_scope" {
  description = "Scope specification slug for static scope"
  value       = module.scope_definition_static_scope.service_slug
}


output "service_specification_slug_rds_server" {
  description = "Slug of the service created by service_definition for Azure cosmos db"
  value       = module.service_definition_rds_server.service_specification_slug
}

output "service_specification_id_rds_server" {
  description = "Slug of the service created by service_definition for Azure cosmos db"
  value       = module.service_definition_rds_server.service_specification_id
}


output "service_specification_slug_rds_db" {
  description = "Slug of the service created by service_definition for Azure cosmos db"
  value       = module.service_definition_rds_db.service_specification_slug
}

output "service_specification_id_rds_dn" {
  description = "Slug of the service created by service_definition for Azure cosmos db"
  value       = module.service_definition_rds_db.service_specification_id
}