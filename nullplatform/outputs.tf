################################################################################
# Outputs - Nullplatform
################################################################################

output "service_specification_id" {
  description = "ID of the service specification created by the containers scope definition"
  value       = module.scope_definitions["containers"].service_specification_id
}

output "service_slug" {
  description = "Slug of the service created by the containers scope definition"
  value       = module.scope_definitions["containers"].service_slug
}

output "scope_specification_id" {
  description = "Scope specification ID (from service_specification)"
  value       = module.scope_definitions["containers"].service_specification_id
}

output "scope_specification_slug" {
  description = "Scope specification slug (from service_slug)"
  value       = module.scope_definitions["containers"].service_slug
}

output "service_specification_id_scheduled_task" {
  description = "ID of the service specification created by the scheduled task scope definition"
  value       = module.scope_definitions["scheduled_tasks"].service_specification_id
}

output "service_slug_scheduled_task" {
  description = "Slug of the service created by the scheduled task scope definition"
  value       = module.scope_definitions["scheduled_tasks"].service_slug
}

output "scope_specification_id_scheduled_task" {
  description = "Scope specification ID for scheduled tasks"
  value       = module.scope_definitions["scheduled_tasks"].service_specification_id
}

output "scope_specification_slug_scheduled_task" {
  description = "Scope specification slug for scheduled tasks"
  value       = module.scope_definitions["scheduled_tasks"].service_slug
}

output "scope_specification_id_static_scope" {
  description = "Scope specification ID for static scope"
  value       = module.scope_definitions["static_files"].service_specification_id
}

output "scope_specification_slug_static_scope" {
  description = "Scope specification slug for static scope"
  value       = module.scope_definitions["static_files"].service_slug
}

output "service_specification_slug_rds_server" {
  description = "Slug of the RDS Postgres Server service specification"
  value       = module.service_definitions["rds_postgres_server"].service_specification_slug
}

output "service_specification_id_rds_server" {
  description = "ID of the RDS Postgres Server service specification"
  value       = module.service_definitions["rds_postgres_server"].service_specification_id
}

output "service_specification_slug_rds_db" {
  description = "Slug of the RDS Postgres Database service specification"
  value       = module.service_definitions["rds_postgres_db"].service_specification_slug
}

output "service_specification_id_rds_dn" {
  description = "ID of the RDS Postgres Database service specification"
  value       = module.service_definitions["rds_postgres_db"].service_specification_id
}

output "service_specification_slug_aws_s3_bucket" {
  description = "Slug of the AWS S3 Bucket service specification"
  value       = module.service_definitions["aws_s3_bucket"].service_specification_slug
}

output "service_specification_id_aws_s3_bucket" {
  description = "ID of the AWS S3 Bucket service specification"
  value       = module.service_definitions["aws_s3_bucket"].service_specification_id
}

output "service_specification_slug_postgres_db" {
  description = "Slug of the Postgres DB (K8s) service specification"
  value       = module.service_definitions["postgres_db_k8s"].service_specification_slug
}

output "service_specification_id_postgres_db" {
  description = "ID of the Postgres DB (K8s) service specification"
  value       = module.service_definitions["postgres_db_k8s"].service_specification_id
}
