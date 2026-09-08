locals {
  cluster_name = "${var.organization_slug}-cluster"
  domain_name  = "${var.organization_slug}.nullapps.io"

  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-aws-services-cluster-agent-role"

  # Reaches the agent pod and the containers worker. CLUSTER_NAME is what the
  # k8s scope's create_role reads; DNS_TYPE is the fallback when the
  # scope-configurations provider carries no networking.dns_type. DOMAIN,
  # USE_ACCOUNT_SLUG and IMAGE_PULL_SECRETS are resolved from the providers
  # and never read from the env, so they are not passed.
  agent_extra_envs = {
    CLUSTER_NAME = module.eks.eks_cluster_name
    NAMESPACE    = "nullplatform-tools"
    DNS_TYPE     = var.dns_type
  }
}
