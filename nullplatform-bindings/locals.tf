locals {
  # Infrastructure - variable overrides remote state
  public_zone_id  = var.public_zone_id != null ? var.public_zone_id : data.terraform_remote_state.infrastructure[0].outputs.public_zone_id
  private_zone_id = var.private_zone_id != null ? var.private_zone_id : data.terraform_remote_state.infrastructure[0].outputs.private_zone_id
  cluster_name    = var.cluster_name != null ? var.cluster_name : data.terraform_remote_state.infrastructure[0].outputs.cluster_name
  domain_name     = var.domain_name != null ? var.domain_name : data.terraform_remote_state.infrastructure[0].outputs.domain_name

  # Nullplatform - always from remote state
  scope_specification_id                 = data.terraform_remote_state.nullplatform.outputs.scope_specification_id
  scope_specification_slug               = data.terraform_remote_state.nullplatform.outputs.scope_specification_slug
  scope_specification_id_scheduled_task   = data.terraform_remote_state.nullplatform.outputs.scope_specification_id_scheduled_task
  scope_specification_slug_scheduled_task = data.terraform_remote_state.nullplatform.outputs.scope_specification_slug_scheduled_task
  scope_specification_id_static_scope   = data.terraform_remote_state.nullplatform.outputs.scope_specification_id_static_scope
  scope_specification_slug_static_scope = data.terraform_remote_state.nullplatform.outputs.scope_specification_slug_static_scope

  service_specification_slug_rds_server = data.terraform_remote_state.nullplatform.outputs.service_specification_slug_rds_server
  service_specification_slug_rds_db = data.terraform_remote_state.nullplatform.outputs.service_specification_slug_rds_db

  service_specification_slug_aws_s3_bucket = data.terraform_remote_state.nullplatform.outputs.service_specification_slug_aws_s3_bucket

  service_specification_slug_postgres_db = data.terraform_remote_state.nullplatform.outputs.service_specification_slug_postgres_db

  vpc_id = data.terraform_remote_state.infrastructure[0].outputs.vpc_id
  vpc_subnets_ids = data.terraform_remote_state.infrastructure[0].outputs.vpc_subnets_ids
  vpc_security_groups_ids  = data.terraform_remote_state.infrastructure[0].outputs.vpc_security_groups_ids





}
