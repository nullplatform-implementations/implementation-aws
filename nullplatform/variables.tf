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

# Declared but unused here: common.tfvars is shared by every layer and an
# undeclared variable warns on every plan.
variable "organization_slug" {
  description = "Nullplatform organization slug. Not read by this layer - declared only so the shared common.tfvars applies without warnings. Used by infrastructure/aws for resource naming."
  type        = string
  default     = null
}

################################################################################
# Scopes
################################################################################

variable "published_scopes" {
  description = "Per-environment configuration for the scopes this organization publishes, keyed like local.published_scopes. 'enabled' toggles registration (default true); 'version' pins the spec repo branch, falling back to the catalog's when unset. The optional 'repository_*' fields override the catalog-derived URL/branch for a specific spec pair (service_spec, scope_template or action_templates)."
  type = map(object({
    enabled                             = optional(bool, true)
    version                             = optional(string)
    repository_service_spec             = optional(string)
    repository_service_spec_version     = optional(string)
    repository_scope_template           = optional(string)
    repository_scope_template_version   = optional(string)
    repository_action_templates         = optional(string)
    repository_action_templates_version = optional(string)
  }))
  default = {}
}

variable "installed_scopes" {
  description = "Per-environment configuration for the scope packages this organization installs, keyed like local.installed_scopes. 'enabled' toggles the installation (default true); 'version' pins another package version (the templates follow its tag, v<version>)."
  type = map(object({
    enabled = optional(bool, true)
    version = optional(string)
  }))
  default = {}
}

################################################################################
# Services
################################################################################

variable "published_services" {
  description = "Per-environment configuration for the services this organization publishes, keyed like local.published_services. 'enabled' toggles registration (default true); 'version' overrides the catalog branch of the spec repo."
  type = map(object({
    enabled = optional(bool, true)
    version = optional(string)
  }))
  default = {}
}

variable "installed_services" {
  description = "Per-environment configuration for the service packages this organization installs, keyed like local.installed_services. 'enabled' toggles the installation (default true); 'version' pins another package version."
  type = map(object({
    enabled = optional(bool, true)
    version = optional(string)
  }))
  default = {}
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

################################################################################
# Packages
################################################################################

