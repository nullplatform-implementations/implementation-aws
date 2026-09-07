terraform {
  required_version = ">= 1.6.0"

  required_providers {
    nullplatform = {
      source  = "nullplatform/nullplatform"
      version = "~> 0.0.102"
    }
  }
}

provider "nullplatform" {
  api_key = var.np_api_key
}
