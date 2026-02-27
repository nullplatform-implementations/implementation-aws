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