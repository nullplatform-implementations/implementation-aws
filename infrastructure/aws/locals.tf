locals {
  cluster_name = "${var.organization_slug}-cluster"
  domain_name  = "${var.organization_slug}.nullapps.io"

  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-aws-services-cluster-agent-role"

  # Reaches the agent pod and the containers worker. CLUSTER_NAME is what the
  # k8s scope's create_role reads and the module does not put it in the worker
  # env on its own. DNS_TYPE already travels through the module's dns_type
  # input; DOMAIN, USE_ACCOUNT_SLUG, IMAGE_PULL_SECRETS and NAMESPACE are never
  # read from the env by the scope.
  agent_extra_envs = {
    CLUSTER_NAME = module.eks.eks_cluster_name
  }
}
