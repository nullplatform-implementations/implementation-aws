locals {
  ##############################################################################
  # Scope definitions catalog
  #
  # Static, code-owned description of every scope this organization can register.
  # The per-environment toggles (enabled / version / repo overrides) live in
  # var.scope_definitions and are merged in below.
  ##############################################################################

  containers_definition = {
    service_spec_name          = "Containers"
    service_spec_description   = "Docker containers on pods"
    service_path               = "k8s"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "main"
    create_scope_configuration = false
    action_spec_names = [
      "create-scope",
      "delete-scope",
      "start-initial",
      "start-blue-green",
      "finalize-blue-green",
      "rollback-deployment",
      "delete-deployment",
      "switch-traffic",
      "set-desired-instance-count",
      "pause-autoscaling",
      "resume-autoscaling",
      "restart-pods",
      "kill-instances",
      "diagnose-deployment",
      "diagnose-scope"
    ]
  }


  scheduled_tasks_definition = {
    service_spec_name          = "Scheduled Task"
    service_spec_description   = "Allows you to deploy periodic jobs in Kubernetes"
    service_path               = "scheduled_task"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "main"
    create_scope_configuration = false
    action_spec_names = [
      "create-scope",
      "delete-scope",
      "start-initial",
      "start-blue-green",
      "finalize-blue-green",
      "rollback-deployment",
      "delete-deployment",
      "trigger",
    ]
  }

  static_files_definition = {
    service_spec_name          = "Static Scope"
    service_spec_description   = "Allows you to deploy static to S3"
    service_path               = "static-files"
    repository_org             = "nullplatform"
    repository_name            = "scopes-static-files"
    version                    = "1.0.0"
    create_scope_configuration = true
    action_spec_names = [
      "create-scope",
      "delete-scope",
      "start-initial",
      "start-blue-green",
      "finalize-blue-green",
      "rollback-deployment",
      "delete-deployment",
    ]
  }

  aws_lambda_definition = {
    service_spec_name          = "AWS Lambda Agustin"
    service_spec_description   = "AWS Lambda"
    service_path               = "lambda"
    repository_org             = "nullplatform"
    repository_name            = "scopes-lambda"
    version                    = "1.0.0"
    create_scope_configuration = true
    action_spec_names = [
      "adjust-provisioned-concurrency",
      "adjust-reserved-concurrency",
      "create-scope",
      "delete-deployment",
      "delete-scope",
      "diagnose-deployment",
      "diagnose-scope",
      "finalize-blue-green",
      "invoke",
      "rollback-deployment",
      "start-blue-green",
      "start-initial",
      "switch-traffic",
      "update-scope",
    ]
  }

  scope_definitions_catalog = {
    containers      = local.containers_definition
    scheduled_tasks = local.scheduled_tasks_definition
    static_files    = local.static_files_definition
    aws_lambda      = local.aws_lambda_definition
  }

  # Merge the catalog with per-environment overrides from var.scope_definitions
  # and keep only the entries toggled on. The repository_* fields fall back to
  # the catalog-derived raw.githubusercontent.com URL unless an override is set.
  scope_definitions_enabled = {
    for k, v in local.scope_definitions_catalog : k => merge(v, {
      version        = coalesce(try(var.scope_definitions[k].version, null), v.version)
      repository_url = "https://raw.githubusercontent.com/${v.repository_org}/${v.repository_name}/refs/heads"

      repository_service_spec             = try(var.scope_definitions[k].repository_service_spec, null)
      repository_service_spec_version     = try(var.scope_definitions[k].repository_service_spec_version, null)
      repository_scope_template           = try(var.scope_definitions[k].repository_scope_template, null)
      repository_scope_template_version   = try(var.scope_definitions[k].repository_scope_template_version, null)
      repository_action_templates         = try(var.scope_definitions[k].repository_action_templates, null)
      repository_action_templates_version = try(var.scope_definitions[k].repository_action_templates_version, null)
    })
    if try(var.scope_definitions[k].enabled, true)
  }

  ##############################################################################
  # Service definitions catalog
  ##############################################################################

  rds_postgres_server_definition = {
    repository_org    = "nullplatform"
    repository_name   = "services"
    repository_branch = "1.0.0"
    service_path      = "databases/rds-postgres-server"
    service_name      = "RDS Postgres Server - Agustin Test"
    available_links   = ["connect"]
    available_actions = []
  }

  rds_postgres_db_definition = {
    repository_org    = "nullplatform"
    repository_name   = "services"
    repository_branch = "1.0.0"
    service_path      = "databases/rds-postgres-db"
    service_name      = "RDS Postgres Database - Agustin Test"
    available_links   = ["connect"]
    available_actions = []
  }

  aws_s3_bucket_definition = {
    repository_org    = "nullplatform"
    repository_name   = "services-s-3"
    repository_branch = "1.0.0"
    service_path      = "aws-s3-bucket"
    service_name      = "AWS S3 Bucket - Agent K8s"
    available_links   = ["connect"]
    available_actions = []
  }

  postgres_db_k8s_definition = {
    repository_org    = "nullplatform"
    repository_name   = "services-postgresql-k-8-s"
    repository_branch = "main"
    service_path      = "postgres/k8s"
    service_name      = "Postgres DB K8s - Agustin Test"
    available_links   = ["database-user"]
    available_actions = ["run-ddl-query", "run-dml-query"]
  }

  service_definitions_catalog = {
    rds_postgres_server = local.rds_postgres_server_definition
    rds_postgres_db     = local.rds_postgres_db_definition
    aws_s3_bucket       = local.aws_s3_bucket_definition
    postgres_db_k8s     = local.postgres_db_k8s_definition
  }

  # version (when provided) overrides the catalog branch; otherwise the catalog
  # branch is kept so service-specific branches (e.g. postgres proposal) survive.
  service_definitions_enabled = {
    for k, v in local.service_definitions_catalog : k => merge(v, {
      repository_branch = coalesce(try(var.service_definitions[k].version, null), v.repository_branch)
    })
    if try(var.service_definitions[k].enabled, true)
  }

  ##############################################################################
  # Dimensions catalog
  ##############################################################################

  dimensions_catalog = {
    environment = { name = "Environment", order = 1, values = ["development", "staging", "production"] }
    region      = { name = "Region", order = 2, values = ["us-east-1", "us-west-1"] }
    cloud       = { name = "Cloud", order = 3, values = ["ORACLE", "GCP"] }
  }

  # Per-environment overrides from var.dimensions: 'enabled' toggles the
  # dimension, 'values' overrides the catalog value list when provided.
  dimensions_enabled = {
    for k, v in local.dimensions_catalog : k => merge(v, {
      values = coalesce(try(var.dimensions[k].values, null), v.values)
    })
    if try(var.dimensions[k].enabled, true)
  }
}
