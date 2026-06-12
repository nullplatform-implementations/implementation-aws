###############################################################################
# RDS Setup for Nullplatform - Consolidated Reference
#
# This file contains ALL the pieces needed to enable RDS (Postgres) services
# in a nullplatform AWS implementation. It spans 3 layers:
#   1. infrastructure/aws   - IAM policies + agent role attachment
#   2. nullplatform          - Service definitions + outputs
#   3. nullplatform-bindings - API keys + channel associations
###############################################################################


###############################################################################
# ========== LAYER 1: infrastructure/aws ==========
###############################################################################

# --- IAM Policies -----------------------------------------------------------

resource "aws_iam_policy" "nullplatform_rds_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_rds_policy"
  description = "Policy for managing RDS instances and subnet groups"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:DescribeDBInstances",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBSubnetGroup",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeOrderableDBInstanceOptions",
          "rds:DescribeOptionGroups",
          "iam:CreateServiceLinkedRole"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "nullplatform_rds_sg_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_rds_sg_policy"
  description = "Policy for managing EC2 security groups for RDS"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:CreateTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroupRules"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "nullplatform_rds_s3_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_rds_s3_policy"
  description = "Policy for managing per-service S3 tfstate buckets (np-service-*)"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:HeadBucket",
          "s3:PutBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::np-service-*",
          "arn:aws:s3:::np-service-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "nullplatform_rds_secretsmanager_policy" {
  name        = "nullplatform_${module.eks.eks_cluster_name}_rds_secretsmanager_policy"
  description = "Policy for managing Secrets Manager secrets for RDS master password"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# --- Agent IAM Role - additional_policies ------------------------------------
# These policies are attached to the agent IAM role via additional_policies:
#
# module "agent_iam" {
#   source = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/iam/agent?ref=v1.39.0"
#
#   aws_iam_openid_connect_provider_arn = module.eks.eks_oidc_provider_arn
#   agent_namespace                     = var.agent_namespace
#   cluster_name                        = module.eks.eks_cluster_name
#
#   additional_policies = {
#     "rds_policy"              = aws_iam_policy.nullplatform_rds_policy.arn
#     "rds_secret_manager_policy" = aws_iam_policy.nullplatform_rds_secretsmanager_policy.arn
#     "rds_s3_policy"           = aws_iam_policy.nullplatform_rds_s3_policy.arn
#     "rds_sg_policy"           = aws_iam_policy.nullplatform_rds_sg_policy.arn
#   }
# }


###############################################################################
# ========== LAYER 2: nullplatform ==========
###############################################################################

# --- Service Definitions -----------------------------------------------------

module "service_definition_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v4.3.0"

  nrn               = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services"
  repository_branch = "feature/add-rds-postgress"
  service_path      = "databases/rds-postgres-server"
  service_name      = "RDS Postgres Server"
}

module "service_definition_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v4.3.0"

  nrn               = var.nrn
  repository_org    = "nullplatform"
  repository_name   = "services"
  repository_branch = "feature/add-rds-postgress"
  service_path      = "databases/rds-postgres-db"
  service_name      = "RDS Postgres Database"
}

# --- Outputs (nullplatform layer) --------------------------------------------

output "service_specification_slug_rds_server" {
  description = "Service specification slug for RDS Postgres Server"
  value       = module.service_definition_rds_server.service_specification_slug
}

output "service_specification_id_rds_server" {
  description = "Service specification ID for RDS Postgres Server"
  value       = module.service_definition_rds_server.service_specification_id
}

output "service_specification_slug_rds_db" {
  description = "Service specification slug for RDS Postgres Database"
  value       = module.service_definition_rds_db.service_specification_slug
}

output "service_specification_id_rds_db" {
  description = "Service specification ID for RDS Postgres Database"
  value       = module.service_definition_rds_db.service_specification_id
}


###############################################################################
# ========== LAYER 3: nullplatform-bindings ==========
###############################################################################

# --- Locals (from remote state) ----------------------------------------------
#
# locals {
#   service_specs = data.terraform_remote_state.nullplatform.outputs.service_definitions
#   service_specification_slug_rds_server = local.service_specs["rds_postgres_server"].slug
#   service_specification_slug_rds_db     = local.service_specs["rds_postgres_db"].slug
# }

# --- API Keys ----------------------------------------------------------------

module "service_notification_api_key_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v4.3.0"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_rds_server
}

module "service_notification_api_key_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/api_key?ref=v4.3.0"

  type               = "service_notification"
  nrn                = var.nrn
  specification_slug = local.service_specification_slug_rds_db
}

# --- Channel Associations (Service to Agent) ---------------------------------

module "service_definition_channel_association_rds_server" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v4.3.0"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_rds_server.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_rds_server
  repository_service_spec_repo = "nullplatform/services"
  service_path                 = "databases/rds-postgres-server"
}

module "service_definition_channel_association_rds_db" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v4.3.0"

  nrn                          = var.nrn
  api_key                      = module.service_notification_api_key_rds_db.api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = local.service_specification_slug_rds_db
  repository_service_spec_repo = "nullplatform/services"
  service_path                 = "databases/rds-postgres-db"
}

# --- Agent extra repos -------------------------------------------------------
# The agent needs to clone the services repo. Add this to the agent module:
#
# module "agent" {
#   ...
#   agent_repos_extra = [
#     "https://github.com/nullplatform/services.git#feature/add-rds-postgress"
#   ]
# }
