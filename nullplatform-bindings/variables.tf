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

variable "parameter_store_instances" {
  description = <<-EOT
    Provider instances to create. Map key is a stable identifier (used in for_each).
    Each entry carries its own NRN, dimensions, KMS key (for SecureString), tier, and the
    parameter sensibility set this instance handles (secret / non_secret / both).
    Each instance also gets its own agent API key + notification channel (anchored at the
    instance NRN) unless notification_channel_enabled=false. Fields:
      notification_channel_enabled — create the agent channel + its API key for this instance (default true).
      tags_selectors               — tag key/value pairs the agent uses to match this instance's channel
                                      against scope tags (e.g. { environment = "development" }).
  EOT
  type = map(object({
    nrn                          = string
    dimensions                   = map(string)
    kms_key_id                   = string
    tier                         = string
    applies_to                   = list(string)
    notification_channel_enabled = optional(bool, true)
    tags_selectors               = optional(map(string), {})
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