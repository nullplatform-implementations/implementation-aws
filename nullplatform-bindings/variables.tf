################################################################################
# Nullplatform Configuration
################################################################################

variable "nrn" {
  description = "Nullplatform Resource Name"
  type        = string
}

variable "np_api_key" {
  description = "API key for authenticating with the Nullplatform API"
  type        = string
  sensitive   = true
}

variable "organization_slug" {
  description = "Organization slug"
  type        = string
}

variable "tags_selectors" {
  description = "Map of tags used to select and filter channels and agents"
  type        = map(string)
}

################################################################################
# GitHub Configuration
################################################################################

variable "github_organization" {
  description = "Name of the GitHub organization"
  type        = string
}

variable "github_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}

################################################################################
# AWS Configuration
################################################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

################################################################################
# Infrastructure values (optional - falls back to remote state)
################################################################################

variable "public_zone_id" {
  description = "Route53 public hosted zone ID. If null, read from infrastructure remote state"
  type        = string
  default     = null
}

variable "private_zone_id" {
  description = "Route53 private hosted zone ID. If null, read from infrastructure remote state"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "EKS cluster name. If null, read from infrastructure remote state"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "Domain name for applications. If null, read from infrastructure remote state"
  type        = string
  default     = null
}


variable "extra_visible_to_nrns" {
  description = "Additional NRNs that should see the provider specification besides var.nrn and the per-instance NRNs."
  type        = list(string)
  default     = []
}

variable "template_path" {
  description = "Path (within the parameters repository) to the provider specification template consumed by the parameter_storage_definition module."
  type        = string
  default     = "parameters/providers/aws-parameter-store/specs/install/aws-parameter-store-configuration.json.tpl"
}

variable "repository_parameter_storage_spec_branch" {
  description = "Branch of the parameters repository from which the parameter storage spec is fetched."
  type        = string
  default     = "main"
}

variable "repository_parameter_storage_spec" {
  description = "Base raw URL of the parameters repository hosting the parameter storage spec."
  type        = string
  default     = "https://raw.githubusercontent.com/nullplatform/parameters-provider/refs/heads"
}

variable "parameter_store_instances" {
  description = <<-EOT
    Provider instances to create. Map key is a stable identifier (used in for_each).
    Each entry carries its own NRN, dimensions, and a provider-specific `attributes`
    object matching the provider spec schema (sensibility + setup). Instances with
    enable_notification_channel=true also get their own agent API key + notification
    channel (anchored at the instance NRN). Fields:
      attributes                  — provider config matching the spec schema (sensibility.applies_to, setup.kms_key_id, setup.tier).
      enable_notification_channel — create the agent API key + notification channel for this instance (default false).
      tags_selectors              — tag key/value pairs the agent uses to match this instance's channel
                                    against scope tags (e.g. { environment = "development" }).
  EOT
  type = map(object({
    nrn                         = string
    dimensions                  = map(string)
    enable_notification_channel = optional(bool, false)
    tags_selectors              = optional(map(string), {})
    attributes = object({
      sensibility = object({
        applies_to = list(string)
      })
      setup = object({
        kms_key_id = string
        tier       = string
      })
    })
  }))
  default = {}
}

variable "secrets_manager_template_path" {
  description = "Path (within the parameters repository) to the AWS Secrets Manager provider specification template. Reuses repository_parameter_storage_spec / _branch for the repo + ref."
  type        = string
  default     = "parameters/providers/aws-secrets-manager/specs/install/aws-secrets-manager-configuration.json.tpl"
}

variable "secrets_manager_instances" {
  description = <<-EOT
    Secrets Manager provider instances to create. Map key is a stable identifier (used in for_each).
    Same shape as parameter_store_instances but attributes.setup has no `tier` (Secrets Manager omits it).
      attributes                  — provider config matching the spec schema (sensibility.applies_to, setup.kms_key_id).
      enable_notification_channel — create the agent API key + notification channel for this instance (default false).
      tags_selectors              — tag key/value pairs the agent uses to match this instance's channel
                                    against scope tags (e.g. { environment = "development" }).
  EOT
  type = map(object({
    nrn                         = string
    dimensions                  = map(string)
    enable_notification_channel = optional(bool, false)
    tags_selectors              = optional(map(string), {})
    attributes = object({
      sensibility = object({
        applies_to = list(string)
      })
      setup = object({
        kms_key_id = string
      })
    })
  }))
  default = {}
}

variable "iam_role" {
  description = <<-EOT
    Optionally create the AWS IAM role with least-privilege permissions this provider needs.
    Fields:
      enable             — set true to create the role + inline policy.
      name               — role name (required when enable=true).
      mode               — "default" (ssm + default KMS) or "with_kms" (adds customer-managed KMS perms).
      trusted_principals — list of ARNs allowed to assume the role. Defaults to the current account root
                           (any principal in the account, further controlled by their own IAM policies).
      kms_key_arn        — required when mode="with_kms". The customer-managed KMS key the role can use.
    The role's ARN is exposed via the `iam_role_arn` output so operators can plug it into the
    identity-access-control provider's iam_role_arns.arns[].arn field with selector="parameter_store".
  EOT
  type = object({
    enable             = bool
    name               = string
    mode               = optional(string, "default")
    trusted_principals = optional(list(string), [])
    kms_key_arn        = optional(string, "")
  })
  default = {
    enable = false
    name   = ""
  }
}