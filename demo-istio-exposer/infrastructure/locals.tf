locals {
  cluster_name = "${var.name_prefix}-cluster"
  domain_name  = "demo.${var.parent_domain}"

  # Se arma a mano y no por output del modulo para cortar el ciclo agent_iam <-> scope_requirements_k8s.
  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-${local.cluster_name}-agent-role"
}
