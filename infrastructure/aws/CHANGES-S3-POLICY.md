# Cambios: S3 Bucket Policy para Static Scopes (CloudFront)


### 2. `main.tf` - Bucket y policy

Se cambio el bucket de `assets-aws-services-main` (us-east-1) a `assets-aws-services-main-sao-paulo` (sa-east-1) y se agrego la policy con `SourceAccount`:

resource "aws_s3_bucket" "assets" {
  provider = aws.sa_east_1
  bucket   = "assets-aws-services-main-sao-paulo"
}

resource "aws_s3_bucket_policy" "static" {
  provider = aws.sa_east_1
  bucket   = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}
