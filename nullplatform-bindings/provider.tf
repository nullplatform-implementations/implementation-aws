terraform {
  required_providers {
    nullplatform = {
      source  = "nullplatform/nullplatform"
      version = "~> 0.0.77"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "nullplatform" {
  api_key = var.np_api_key
}

provider "aws" {
  region = var.aws_region
}
