locals {
  cluster_name = "${var.organization_slug}-cluster"
  domain_name  = "${var.organization_slug}.nullapps.io"

  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-aws-services-cluster-agent-role"
}
