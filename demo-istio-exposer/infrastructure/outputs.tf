output "cluster_name" { value = module.eks.eks_cluster_name }
output "vpc_id" { value = module.vpc.vpc_id }
output "domain_name" { value = local.domain_name }

output "public_zone_id" { value = module.dns.public_zone_id }
output "private_zone_id" { value = module.dns.private_zone_id }

output "public_gateway_sg_id" { value = module.security.public_gateway_security_group_id }
output "private_gateway_sg_id" { value = module.security.private_gateway_security_group_id }

output "k8s_assume_role_arn" { value = module.scope_requirements_k8s.permissions_role_arn }
output "cognito_user_pool_arn" { value = aws_cognito_user_pool.demo.arn }
