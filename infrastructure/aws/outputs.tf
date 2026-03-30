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