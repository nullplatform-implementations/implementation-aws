# Approvals: production deployments of this account are decided by a checklist.
#
# Both modules come from tofu-modules PR #703, not released yet: they are pinned
# to its head commit. Move them to the release tag once it is published.
#
# The checklist's item is resolved outside this configuration: the http
# notification channel for kind np-deploy-window-check, its workflow and the
# Deploy calendar extension.

# Any change of description or definition publishes a new version, and the
# action below moves to it in the same apply. The name is the identity: a new
# name replaces the specification, and a used name cannot be created again.
module "prod_deployment_checklist" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/approvals/checklist?ref=0c09f1f155602858947891570ca30b6268570950"

  nrn         = var.nrn
  name        = "AWS Services PROD deployment checklist"
  description = "Deployments a production de la account AWS Services: aprobados si no hay freeze en el calendario Deployments Nullplatform; con freeze quedan pendientes y se puede pedir revisión manual (Slack #notification-demo)."
  definition  = jsondecode(file("${path.module}/checklists/aws-services-prod-deployment.json"))
}

module "prod_deployment_approval" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/approvals/action?ref=0c09f1f155602858947891570ca30b6268570950"

  nrn        = var.nrn
  action     = "deployment:create"
  dimensions = { environment = "production" }

  checklist = {
    specification_id = module.prod_deployment_checklist.current_version_id
    # pending: a failed checklist keeps the request waiting, and the requester
    # can ask for a manual review.
    on_fail = "pending"
  }
}
