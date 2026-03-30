# =============================================================================
# Scope Definition - Containers
# =============================================================================
module "scope_definition" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.39.0"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path
  service_spec_name        = var.service_spec_name
  service_spec_description = var.service_spec_description
  action_spec_names        = var.action_spec_names
}

# =============================================================================
# Scope Definition - Scheduled Tasks
# =============================================================================
module "scope_definition_scheduled_task" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.39.0"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path_scheduled_task
  service_spec_name        = var.service_spec_name_scheduled_task
  service_spec_description = var.service_spec_description_scheduled_task
  action_spec_names        = var.action_spec_names_scheduled_task
}


# =============================================================================
# Scope Definition - Static Scope
# =============================================================================
module "scope_definition_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_definition?ref=v1.48.3"

  nrn        = var.nrn
  np_api_key = var.np_api_key

  service_path             = var.service_path_static_scope
  service_spec_name        = var.service_spec_name_static_scope
  service_spec_description = var.service_spec_description_static_scope
  action_spec_names        = var.action_spec_names_static_scope
  create_scope_configuration = true

  repository_service_spec      = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_service_spec_branch     = "main"
  repository_scope_template    = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_scope_template_branch   = "main"
  repository_action_templates  = "https://raw.githubusercontent.com/nullplatform/scopes-static-files/refs/heads"
  repository_action_templates_branch = "main"
}


# =============================================================================
# Service Definition - RDS Server (Postgres)
# =============================================================================
module "service_definition_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v1.46.0"
  nrn = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services"
  repository_branch = "main"
  service_path      = "databases/rds-postgres-server"
  service_name      = "RDS Postgres Server - Agustin Test"
}


# =============================================================================
# Service Definition - RDS Database (Postgres)
# =============================================================================
module "service_definition_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v1.46.0"
  nrn = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services"
  repository_branch = "main"
  service_path      = "databases/rds-postgres-db"
  service_name      = "RDS Postgres Database - Agustin Test"
}


# =============================================================================
# Scope Configuration - Static Scope
# =============================================================================
module "scope_configuration_static_scope" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/scope_configuration?ref=feature/scope-configuration-module"

  nrn                       = var.nrn
  np_api_key                = var.np_api_key
  provider_specification_slug = module.scope_definition_static_scope.provider_specification_slug
  attributes = {
    cloud_provider = "aws"
    provider = {
      aws_region       = "sa-east-1"
      aws_state_bucket = "tf-state-0269fb2df210b43c-sao-pabloe"
    }
    distribution = {
      aws_distribution = "cloudfront"
    }
    network = {
      aws_network               = "route53"
      aws_hosted_public_zone_id = "Z071237515YM3PL1X3KX"
    }
  }
}

# =============================================================================
# Dimensions
# =============================================================================
module "dimensions" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/dimensions?ref=v1.39.0"

  nrn          = var.nrn
  np_api_key   = var.np_api_key
  environments = var.environments
}
