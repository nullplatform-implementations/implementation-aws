################################################################################
# AWS Provider Configuration
################################################################################

variable "aws_profile" {
  description = "(Optional) AWS CLI profile name to use for provider authentication. If not set, the provider's default credentials chain will be used."
  type        = string
  nullable    = true
}

variable "aws_region" {
  description = "AWS region where resources will be created (e.g. us-east-1)."
  type        = string
}

################################################################################
# VPC Configuration
################################################################################

variable "organization" {
  description = "The name of the organization in nullplatform."
  type        = string
}

variable "account" {
  description = "Target AWS account identifier where the infrastructure will be deployed (ID or name used by your workflow)."
  type        = string
  default     = "core"
}

variable "vpc" {
  description = <<EOF
VPC configuration map. Required keys: cidr_block, azs, private_subnets, public_subnets.
Example (HCL):
{
  cidr_block      = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]
}
EOF
  type        = any
}

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

variable "k8s_provider" {
  description = "Cloud provider identifier for Nullplatform (e.g., eks)"
  type        = string
  default     = "eks"
}

variable "cloud_provider" {
  description = "Identifier of the cloud provider (e.g. \"aws\", \"azure\"). Defaults to 'aws' for this example."
  type        = string
  default     = "aws"
}

################################################################################
# Agent Configuration
################################################################################

variable "agent_namespace" {
  description = <<EOF
Kubernetes namespace where the nullplatform agent will be installed.
If not provided, the consuming module may create its own namespace or use a default.
EOF
  type        = string
  default     = "nullplatform-tools"
}

variable "image_tag" {
  description = "Docker image tag for the Nullplatform agent"
  type        = string
  default     = "aws-0.7.0"
}

variable "tags_selectors" {
  description = "Map of tag selectors used to filter or identify resources. Format: map(string => string)."
  type        = map(string)
}

variable "dns_type" {
  description = "Type of DNS provider (e.g., 'azure', 'aws', 'gcp', 'external_dns')"
  type        = string
}

variable "service_template" {
  description = "Path to the service template for Istio"
  type        = string
  default     = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/service.yaml.tpl"
}

variable "initial_ingress_path" {
  description = "Path to the initial ingress template for Istio"
  type        = string
  default     = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/initial-httproute.yaml.tpl"
}

variable "blue_green_ingress_path" {
  description = "Path to the blue-green ingress template for Istio"
  type        = string
  default     = "/root/.np/nullplatform/scopes/k8s/deployment/templates/istio/blue-green-httproute.yaml.tpl"
}

################################################################################
# DNS Configuration
################################################################################

variable "dns_provider_name" {
  description = "DNS provider name"
  type        = string
}

variable "policy" {
  description = "External DNS policy"
  type        = string
}

variable "sources" {
  description = "External DNS sources to watch (e.g. crd, ingress, service, gateway-httproute)"
  type        = list(string)
  default     = ["crd"]
}

variable "organization_slug" {
  description = "Name of the organization"
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the public EKS API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "iam_role_name" {
  description = "Name of the agent IRSA role created by iam_agent; the permissions role trusts it and the agent runs as it"
  type        = string
  default     = ""
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