locals {
  cluster_name = "${var.name_prefix}-cluster"
  domain_name  = "demo.${var.parent_domain}"

  # Patron confirmado en tofu-modules//infrastructure/aws/iam/agent: role_name defaultea a
  # "nullplatform-${cluster_name}-agent-role". Se arma a mano (no via output del modulo) para evitar
  # un ciclo: agent_iam necesita el permissions_role_arn de scope_requirements_k8s, que a su vez
  # necesita este ARN.
  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-${local.cluster_name}-agent-role"
}
