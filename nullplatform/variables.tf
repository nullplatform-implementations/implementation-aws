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
# Scope Definition - Containers
################################################################################

variable "service_path" {
  description = "Path to the service directory within the repository structure"
  type        = string
  default     = "k8s"
}

variable "service_spec_name" {
  description = "Name of the container service specification"
  type        = string
  default     = "Containers"
}

variable "service_spec_description" {
  description = "Description of the container service specification"
  type        = string
  default     = "Docker containers on pods"
}

variable "action_spec_names" {
  description = "List of action specification names for containers"
  type        = list(string)
  default = [
    "create-scope",
    "delete-scope",
    "start-initial",
    "start-blue-green",
    "finalize-blue-green",
    "rollback-deployment",
    "delete-deployment",
    "switch-traffic",
    "set-desired-instance-count",
    "pause-autoscaling",
    "resume-autoscaling",
    "restart-pods",
    "kill-instances",
    "diagnose-deployment",
    "diagnose-scope"
  ]
}

################################################################################
# Scope Definition - Scheduled Tasks
################################################################################

variable "service_path_scheduled_task" {
  description = "Path to the scheduled task service directory"
  type        = string
}

variable "service_spec_name_scheduled_task" {
  description = "Name of the scheduled task service specification"
  type        = string
  default     = "Scheduled Task"
}

variable "service_spec_description_scheduled_task" {
  description = "Description of the scheduled task service specification"
  type        = string
  default     = "Allows you to deploy periodic jobs in Kubernetes"
}

variable "action_spec_names_scheduled_task" {
  description = "List of action specification names for scheduled tasks"
  type        = list(string)
  default = [
    "create-scope",
    "delete-scope",
    "start-initial",
    "start-blue-green",
    "finalize-blue-green",
    "rollback-deployment",
    "delete-deployment",
    "trigger"
  ]
}

################################################################################
# Scope Definition - Static Scopes
################################################################################

variable "service_path_static_scope" {
  description = "Path to the static scope service directory"
  type        = string
  default = "static-files"
}

variable "service_spec_name_static_scope" {
  description = "Name of the static scope service specification"
  type        = string
  default     = "Static Scope"
}

variable "service_spec_description_static_scope" {
  description = "Description of the static scope service specification"
  type        = string
  default     = "Allows you to deploy static to S3"
}


variable "action_spec_names_static_scope" {
  description = "List of action specification names for static scopes"
  type        = list(string)
  default = [
    "create-scope",
    "delete-scope",
    "start-initial",
    "start-blue-green",
    "finalize-blue-green",
    "rollback-deployment",
    "delete-deployment"
  ]
}



################################################################################
# Dimensions
################################################################################

variable "environments" {
  type        = list(string)
  description = "The list of environments"
  default     = ["development", "staging", "production"]
}

variable "regions" {
  type        = list(string)
  description = "The list of regions"
  default     = ["us-east-1", "us-west-1"]
}

################################################################################
# Tags
################################################################################

variable "tags_selectors" {
  description = "Map of tags used to select and filter channels and agents"
  type        = map(string)
}
