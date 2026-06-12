################################################################################
# Nullplatform Configuration
################################################################################

variable "nrn" {
  description = "Nullplatform Resource Name - Unique identifier for Nullplatform resources"
  type        = string
}

variable "np_api_key" {
  description = "API key for authenticating with the Nullplatform API"
  type        = string
  sensitive   = true
}

################################################################################
# Scope definitions
################################################################################

variable "scope_definitions" {
  description = "Per-environment configuration for scope definitions, keyed by scope slug (keys must match local.scope_definitions_catalog). 'enabled' toggles registration (default true); 'version' pins the spec repo branch (default 'main'). The optional 'repository_*' fields override the catalog-derived URL/branch for a specific spec pair (service_spec, scope_template or action_templates)."
  type = map(object({
    enabled                             = optional(bool, true)
    version                             = optional(string, "main")
    repository_service_spec             = optional(string)
    repository_service_spec_version     = optional(string)
    repository_scope_template           = optional(string)
    repository_scope_template_version   = optional(string)
    repository_action_templates         = optional(string)
    repository_action_templates_version = optional(string)
  }))
  default = {
    containers      = { enabled = true }
    scheduled_tasks = { enabled = true }
    static_files    = { enabled = true }
  }
}

################################################################################
# Service definitions
################################################################################

variable "service_definitions" {
  description = "Per-environment configuration for service definitions, keyed by service slug (keys must match local.service_definitions_catalog). 'enabled' toggles registration (default true); 'version' overrides the catalog branch of the spec repo (defaults to the catalog branch)."
  type = map(object({
    enabled = optional(bool, true)
    version = optional(string)
  }))
  default = {
    rds_postgres_server = { enabled = true }
    rds_postgres_db     = { enabled = true }
    aws_s3_bucket       = { enabled = true }
    postgres_db_k8s     = { enabled = true }
  }
}

################################################################################
# Dimensions
################################################################################

variable "dimensions" {
  description = "Per-environment configuration for dimensions, keyed by dimension slug (keys must match local.dimensions_catalog). 'enabled' toggles registration (default true); 'values' overrides the catalog value list when provided."
  type = map(object({
    enabled = optional(bool, true)
    values  = optional(list(string))
  }))
  default = {}
}

################################################################################
# Tags
################################################################################

variable "tags_selectors" {
  description = "Map of tags used to select and filter channels and agents"
  type        = map(string)
}
