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
  description = "Docker image tag for the Nullplatform agent (controlplane-agent). aws-0.11.0+ is required for the worker orchestrator; the -nonroot variant runs as uid 1001 and clones repositories under /home/agent/.np."
  type        = string
  default     = "aws-0.11.0-nonroot"
}

variable "agent_helm_version" {
  description = "nullplatform-agent Helm chart version. 2.37.0+ ships the worker orchestrator."
  type        = string
  default     = "2.37.0"
}

variable "containers_worker_image_digest" {
  description = "Digest of public.ecr.aws/nullplatform/scopes/containers the agent pins as the containers worker image (NP_WORKERS). Must match worker_image_digest in nullplatform/, the digest the containers package publishes. Default: tag v1.15.1."
  type        = string
  default     = "sha256:f5f26ffd6f2d423224463669536ab3d2526467695edfd50222941b86486504e2"

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.containers_worker_image_digest))
    error_message = "containers_worker_image_digest must be an OCI digest formatted as sha256:<64 hex chars>."
  }
}

variable "static_files_worker_image_digest" {
  description = "Digest of public.ecr.aws/nullplatform/scopes/static-files the agent pins as the static-files worker image (NP_WORKERS). Must match the digest the static_files package publishes in nullplatform/. Default: tag v0.5.0."
  type        = string
  default     = "sha256:00cef1dba2f91f99ffc5ab1849dc4fa18d6769cc544865e072a7fea8544df85d"

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.static_files_worker_image_digest))
    error_message = "static_files_worker_image_digest must be an OCI digest formatted as sha256:<64 hex chars>."
  }
}

variable "lambda_worker_image_digest" {
  description = "Digest of public.ecr.aws/nullplatform/scopes/lambda the agent pins as the lambda worker image (NP_WORKERS). Must match the digest the aws_lambda package publishes in nullplatform/. Default: tag v0.4.0."
  type        = string
  default     = "sha256:aefed6168b7d07d83f1d765a14f164f5d80b73743ed3b35af621d368446c0bfd"

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.lambda_worker_image_digest))
    error_message = "lambda_worker_image_digest must be an OCI digest formatted as sha256:<64 hex chars>."
  }
}

variable "scopes_networking_version" {
  description = "Tag of nullplatform/scopes-networking fetched into the lambda worker as its overrides overlay (ALB target group / listener rule, Route53)."
  type        = string
  default     = "v0.1.0"
}

variable "traffic_manager_tag" {
  description = "k8s-traffic-manager image tag, published to the agent as TRAFFIC_CONTAINER_IMAGE."
  type        = string
  default     = "1.8.0"
}

variable "tags_selectors" {
  description = "Map of tag selectors used to filter or identify resources. Format: map(string => string)."
  type        = map(string)
}

variable "dns_type" {
  description = "Type of DNS provider (e.g., 'azure', 'aws', 'gcp', 'external_dns')"
  type        = string
}

# The three istio template paths are read by the containers WORKER, whose image
# bakes the scopes repository under /app/pkg.
variable "service_template" {
  description = "Path to the service template for Istio"
  type        = string
  default     = "/app/pkg/k8s/deployment/templates/istio/service.yaml.tpl"
}

variable "initial_ingress_path" {
  description = "Path to the initial ingress template for Istio"
  type        = string
  default     = "/app/pkg/k8s/deployment/templates/istio/initial-httproute.yaml.tpl"
}

variable "blue_green_ingress_path" {
  description = "Path to the blue-green ingress template for Istio"
  type        = string
  default     = "/app/pkg/k8s/deployment/templates/istio/blue-green-httproute.yaml.tpl"
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

variable "secrets_manager_iam_role" {
  description = <<-EOT
    IAM role for the AWS Secrets Manager parameters provider. Same shape as iam_role.
    mode is "default" (secretsmanager + default KMS) or "kms" (adds customer-managed KMS perms).
    The role's ARN is published to the identity-access-control provider with selector="secret_manager".
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