locals {
  cluster_name = "${var.organization_slug}-cluster"
  domain_name  = "${var.organization_slug}.nullapps.io"

  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-aws-services-cluster-agent-role"

  agent_extra_envs = {
    CLUSTER_NAME       = module.eks.eks_cluster_name
    NAMESPACE          = "nullplatform-tools"
    DNS_TYPE           = var.dns_type
    DOMAIN             = ""
    USE_ACCOUNT_SLUG   = ""
    IMAGE_PULL_SECRETS = ""
  }

  # Mirrors the env the agent module builds for the containers worker
  # (worker_default_env + extra_envs), for workers that run the k8s scope
  # code from the same image under an overlay.
  worker_k8s_env = merge({
    K8S_NAMESPACE           = "nullplatform-tools"
    SERVICE_TEMPLATE        = var.service_template
    INITIAL_INGRESS_PATH    = var.initial_ingress_path
    BLUE_GREEN_INGRESS_PATH = var.blue_green_ingress_path
    TRAFFIC_CONTAINER_IMAGE = "public.ecr.aws/nullplatform/k8s-traffic-manager:${var.traffic_manager_tag}"
    PRIVATE_GATEWAY_NAME    = "gateway-private"
    PUBLIC_GATEWAY_NAME     = "gateway-public"
  }, local.agent_extra_envs)
}
