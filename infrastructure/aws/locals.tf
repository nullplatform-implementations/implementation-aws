locals {
  cluster_name = "${var.organization_slug}-cluster"
  domain_name  = "${var.organization_slug}.nullapps.io"

  agent_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-aws-services-cluster-agent-role"
  iam_enabled    = var.iam_role.enable

  # If trusted_principals isn't provided, default to the current account root.
  # That allows IAM principals within the account to assume the role (subject
  # to their own IAM policies). To lock it down further, pass explicit ARNs.
  effective_trusted_principals = local.iam_enabled ? (
    length(var.iam_role.trusted_principals) > 0
    ? var.iam_role.trusted_principals
    : ["arn:aws:iam::${local.aws_account_id}:root"]
  ) : []

  # Build the policy JSON conditionally at the string level — Terraform's strict
  # typing rejects ternaries that return tuples of differently-shaped objects
  # (base has 4 keys, kms statement adds Condition for the 5th).
  policy_doc = var.iam_role.mode == "with_kms" ? jsonencode({
    Version   = "2012-10-17"
    Statement = [local.base_policy_statement, local.kms_policy_statement]
    }) : jsonencode({
    Version   = "2012-10-17"
    Statement = [local.base_policy_statement]
  })


  base_policy_statement = {
    Sid    = "ManageNullplatformParameters"
    Effect = "Allow"
    Action = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:DeleteParameter",
    ]
    Resource = "arn:aws:ssm:${local.aws_region}:${local.aws_account_id}:parameter/nullplatform/*"
  }

  kms_policy_statement = {
    Sid    = "UseCustomerManagedKmsKey"
    Effect = "Allow"
    Action = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    Resource = var.iam_role.kms_key_arn
    Condition = {
      StringEquals = {
        "kms:ViaService" = "ssm.${local.aws_region}.amazonaws.com"
      }
    }
  }


  aws_account_id = local.iam_enabled ? data.aws_caller_identity.current.account_id : ""
  aws_region     = local.iam_enabled ? data.aws_region.current.region : ""


}
