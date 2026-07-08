output "private_zone_id" {
  description = "The private hosted zone ID"
  value       = module.dns.private_zone_id
}

output "public_zone_id" {
  description = "The public hosted zone ID"
  value       = module.dns.public_zone_id
}

output "cluster_name" {
  description = "The EKS cluster name"
  value       = module.eks.eks_cluster_name
}

output "domain_name" {
  description = "The domain name for applications"
  value       = local.domain_name
}


output "vpc_id" {
  description = "The VPC id where the infrastructure is hosted"
  value       = module.vpc.vpc_id
}

output "vpc_subnets_ids" {
  description = "The VPC subnets ids"
  value       = module.vpc.private_subnets
}

output "vpc_security_groups_ids" {
  description = "The VPC security group IDs"
  value       = module.vpc.security_group_ids
}

output "ecr_application_role_arn" {
  description = "IAM role ARN consumed by nullplatform/asset/ecr for application image pulls"
  value       = module.ecr_iam.application_role_arn
}

output "ecr_build_workflow_access_key_id" {
  description = "Access key ID for the CI/CD build workflow IAM user (created by the build-user module; consumed by nullplatform/asset/ecr and asset/s3)"
  value       = module.ci_build_workflow_user.build_workflow_access_key_id
}

output "ecr_build_workflow_access_key_secret" {
  description = "Secret access key for the CI/CD build workflow IAM user (created by the build-user module; consumed by nullplatform/asset/ecr and asset/s3)"
  value       = module.ci_build_workflow_user.build_workflow_access_key_secret
  sensitive   = true
}

output "lambda_assume_role_arn" {
  description = "ARN of the Lambda assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"lambda\")"
  value       = module.scope_requirements_lambda.permissions_role_arn
}

output "k8s_assume_role_arn" {
  description = "ARN of the K8s assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"k8s\")"
  value       = module.scope_requirements_k8s.permissions_role_arn
}

output "static_files_assume_role_arn" {
  description = "ARN of the static-files assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"static-files\")"
  value       = module.scope_requirements_static_files.permissions_role_arn
}

output "s3_assume_role_arn" {
  description = "ARN of the aws-s3-bucket service assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"s3\")"
  value       = module.service_requirements_s3.permissions_role_arn
}

output "rds_server_assume_role_arn" {
  description = "ARN of the rds-postgres-server service assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"rds-postgres-server\")"
  value       = module.service_requirements_rds_server.permissions_role_arn
}

output "rds_db_assume_role_arn" {
  description = "ARN of the rds-postgres-db service assume-role; consumed by nullplatform-bindings to publish the AWS IAM provider (selector \"rds-postgres-db\")"
  value       = module.service_requirements_rds_db.permissions_role_arn
}



output "iam_role_arn" {
  description = "ARN of the Parameter Store IAM role. Wire this into the identity-access-control provider's iam_role_arns.arns[] with selector=\"parameter_store\". Empty when iam_role.enable=false."
  value       = module.parameter_store_requirements.iam_role_arn
}

output "secret_manager_iam_role_arn" {
  description = "ARN of the Secrets Manager IAM role. Wire this into the identity-access-control provider's iam_role_arns.arns[] with selector=\"secret_manager\". Empty when secrets_manager_iam_role.enable=false."
  value       = module.secrets_manager_requirements.iam_role_arn
}

