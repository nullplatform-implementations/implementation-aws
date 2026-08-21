variable "nrn" {
  description = "NRN de la account donde se registra el agente y las specs."
  type        = string
}

variable "np_api_key" {
  description = "API key de nullplatform de la org 1698562351."
  type        = string
  sensitive   = true
}

variable "aws_profile" {
  description = "Perfil AWS. En esta maquina es 'implementations' (minuscula)."
  type        = string
  default     = ""
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  description = "Prefijo de todos los recursos. Deriva cluster_name y domain_name."
  type        = string
  default     = "uala-demo"
}

variable "parent_domain" {
  description = "Zona padre publica donde se crea la delegacion NS del subdominio de la demo."
  type        = string
  default     = "aws-services.nullapps.io"
}

variable "parent_public_zone_id" {
  description = "Zone id de parent_domain."
  type        = string
}

variable "vpc" {
  description = "CIDR y subnets. No solapar con el 10.0.0.0/16 del cluster compartido."
  type = object({
    cidr_block      = string
    azs             = list(string)
    private_subnets = list(string)
    public_subnets  = list(string)
  })
}

variable "tags_selectors" {
  description = "Tags del agente de la demo. Distintos del agente compartido (owner=aws-services) para que los canales de la demo no le peguen al cluster viejo."
  type        = map(string)
  default     = { owner = "uala-demo" }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs permitidos contra el endpoint publico del API server de EKS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
