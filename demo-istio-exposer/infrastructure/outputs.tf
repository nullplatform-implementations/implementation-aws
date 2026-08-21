output "cluster_name" { value = module.eks.eks_cluster_name }
output "vpc_id" { value = module.vpc.vpc_id }
output "domain_name" { value = local.domain_name }

output "public_zone_id" { value = module.dns.public_zone_id }
output "private_zone_id" { value = module.dns.private_zone_id }
