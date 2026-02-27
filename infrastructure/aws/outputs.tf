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