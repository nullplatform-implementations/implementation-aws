variable "nrn" {
  type = string
}

variable "np_api_key" {
  type      = string
  sensitive = true
}

variable "account_id" {
  description = "Id de account de nullplatform donde se crea el namespace de la demo."
  type        = number
  default     = 1372325109
}
