terraform {
  backend "s3" {
    bucket  = "tf-state-0269fb2df210b43c"
    key     = "nullplatform-bindings.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "providers-test"
  }
}
