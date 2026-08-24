variable "nrn" {
  type = string
}

variable "np_api_key" {
  type      = string
  sensitive = true
}

variable "tags_selectors" {
  description = "Tags del agente de la demo. Tiene que ser identico al del layer infrastructure/, o el canal selecciona un agente que no existe."
  type        = map(string)
}
