#
# Backend Module - Variables
#

variable "force_destroy" {
  type        = bool
  description = "Allow destruction of S3 bucket even if it contains objects"
  default     = false
}

variable "aws_region" {
  type        = string
  description = "AWS region where the backend resources will be created"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use for authentication"
}
