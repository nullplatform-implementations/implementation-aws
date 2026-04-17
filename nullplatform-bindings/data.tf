################################################################################
# Remote State - Infrastructure (optional, used when zone IDs not provided)
################################################################################

data "terraform_remote_state" "infrastructure" {
  count   = var.public_zone_id == null ? 1 : 0
  backend = "s3"
  config = {
    bucket  = "tf-state-0269fb2df210b43c"
    key     = "infrastructure.tfstate"
    region  = "us-east-1"
    profile = "Implementations"
  }
}

################################################################################
# Remote State - Nullplatform
################################################################################

data "terraform_remote_state" "nullplatform" {
  backend = "s3"
  config = {
    bucket  = "tf-state-0269fb2df210b43c"
    key     = "nullplatform.tfstate"
    region  = "us-east-1"
    profile = "Implementations"
  }
}
