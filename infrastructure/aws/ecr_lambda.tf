# =============================================================================
# Lambda placeholder image registry
#
# Lambda container functions must pull their image from a PRIVATE ECR repo in
# the same account/region (public.ecr.aws is rejected). Scope creation
# bootstraps each Lambda with this placeholder image until the first real
# deployment replaces it. The agent points at this repo via
# PLACEHOLDER_IMAGE_URI_DEFAULT (set in the agent's extra_envs).
#
# Terraform manages the repository and the pull policy; it does NOT push images.
# The placeholder image must be mirrored once (requires `crane`):
#
#   ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
#   REGISTRY="$ACCOUNT.dkr.ecr.<region>.amazonaws.com"
#   aws ecr get-login-password --region <region> \
#     | crane auth login --username AWS --password-stdin "$REGISTRY"
#   for arch in amd64 arm64; do
#     crane copy --platform linux/$arch \
#       public.ecr.aws/nullplatform/aws-lambda/nullplatform-lambda-placeholder:latest \
#       "$REGISTRY/aws-lambda/nullplatform-lambda-placeholder:latest-$arch"
#   done
# =============================================================================

resource "aws_ecr_repository" "lambda_placeholder" {
  name                 = "aws-lambda/nullplatform-lambda-placeholder"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Allow the Lambda service to pull the placeholder image.
resource "aws_ecr_repository_policy" "lambda_placeholder" {
  repository = aws_ecr_repository.lambda_placeholder.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [{
      Sid       = "LambdaECRImageRetrievalPolicy"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
    }]
  })
}
