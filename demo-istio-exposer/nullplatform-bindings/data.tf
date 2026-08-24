data "terraform_remote_state" "nullplatform" {
  backend = "s3"
  config = {
    bucket  = "tf-state-0269fb2df210b43c"
    key     = "demo-istio-exposer/nullplatform.tfstate"
    region  = "us-east-1"
    profile = "implementations"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket  = "tf-state-0269fb2df210b43c"
    key     = "demo-istio-exposer/infrastructure.tfstate"
    region  = "us-east-1"
    profile = "implementations"
  }
}
