# =============================================================================
# State migration: individual modules -> for_each instances
#
# Maps each previously hardcoded module to its new keyed address in the
# scope_definitions / service_definitions for_each maps, so OpenTofu treats
# this as a rename (no destroy/create) of the underlying nullplatform specs.
# These blocks are safe to remove once the migration has been applied in every
# environment that consumed this configuration.
# =============================================================================

moved {
  from = module.scope_definition
  to   = module.scope_definitions["containers"]
}

moved {
  from = module.scope_definition_scheduled_task
  to   = module.scope_definitions["scheduled_tasks"]
}

moved {
  from = module.scope_definition_static_scope
  to   = module.scope_definitions["static_files"]
}

moved {
  from = module.service_definition_rds_server
  to   = module.service_definitions["rds_postgres_server"]
}

moved {
  from = module.service_definition_rds_db
  to   = module.service_definitions["rds_postgres_db"]
}

moved {
  from = module.service_definition_aws_s3_bucket
  to   = module.service_definitions["aws_s3_bucket"]
}

moved {
  from = module.service_definition_postgres_db
  to   = module.service_definitions["postgres_db_k8s"]
}

moved {
  from = module.dimension_environment
  to   = module.dimensions["environment"]
}

moved {
  from = module.dimension_region
  to   = module.dimensions["region"]
}

moved {
  from = module.dimension_cloud
  to   = module.dimensions["cloud"]
}
