locals {
  ##############################################################################
  # Scope definitions catalog
  #
  # Static, code-owned description of every scope this organization can register.
  # The per-environment toggles (enabled / version / repo overrides) live in
  # var.scope_definitions and are merged in below.
  #
  # Each entry's version must stay in lockstep with the ?ref= of the matching
  # requirements module in infrastructure/aws AND with the ref in that layer's
  # agent_repos_scope / agent_repos_extra. Nothing fails at plan time if they
  # drift; the first deploy inside the agent does.
  #
  # Packages: package_version is the semver of the package revision THIS
  # configuration publishes. It is independent from the upstream scope version
  # and must be bumped together with `version` or any change to the action set
  # - anything that alters the bill of materials. Worker images are resolved by
  # lookup against the artifact each upstream release registers (visible to
  # every organization) by release tag. A tag re-registered against a new image
  # drifts to it on the next plan, by design.
  # Consequence: a `version` override from tfvars does NOT update the artifact
  # reference; versions are changed here, in the catalog.
  ##############################################################################

  containers_definition = {
    service_spec_name          = "Containers"
    service_spec_description   = "Docker containers on pods"
    service_path               = "k8s"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.16.2"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    package_version = "0.0.2"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/containers"
        tag        = "v1.16.2"
      }
    }]
  }

  scheduled_tasks_definition = {
    service_spec_name          = "Scheduled Task"
    service_spec_description   = "Allows you to deploy periodic jobs in Kubernetes"
    service_path               = "scheduled_task"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.16.2"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    package_version = "0.0.5"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/scheduled-task"
        tag        = "v1.16.2"
      }
    }]
  }

  static_files_definition = {
    service_spec_name          = "Static Scope"
    service_spec_description   = "Allows you to deploy static to S3"
    service_path               = "static-files"
    repository_org             = "nullplatform"
    repository_name            = "scopes-static-files"
    version                    = "v0.5.0"
    repository_ref_type        = "tags"
    create_scope_configuration = true

    package_version = "0.0.5"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/static-files"
        tag        = "v0.5.0"
      }
    }]
  }

  aws_lambda_definition = {
    service_spec_name          = "AWS Lambda Agustin"
    service_spec_description   = "AWS Lambda"
    service_path               = "lambda"
    repository_org             = "nullplatform"
    repository_name            = "scopes-lambda"
    version                    = "v0.5.0"
    repository_ref_type        = "tags"
    create_scope_configuration = true

    package_version = "0.0.5"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/lambda"
        tag        = "v0.5.0"
      }
    }]
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
      repository_url = "https://raw.githubusercontent.com/${v.repository_org}/${v.repository_name}/refs/${v.repository_ref_type}"

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
  #
  # Same package rules as the scopes above: package_version is bumped together
  # with repository_branch (which is also the artifact reference) or any change
  # to the actions/links set. The `impl` artifact points at the service's own
  # implementation repository, which is what the agent runs.
  #
  # repository_branch must be an immutable ref (tofu-modules >= v7.2.0 rejects
  # main/master/head/latest): a tag with repository_ref_type = "tags", or a
  # commit SHA with repository_ref_type = "".
  ##############################################################################

  # Both RDS services come from services-postgresql-rds, which publishes one
  # worker image per service on release.
  rds_postgres_server_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-rds"
    repository_branch   = "v0.2.0"
    repository_ref_type = "tags"
    service_path        = "rds-postgres-server"
    service_name        = "RDS Postgres Server - Agustin Test"
    available_links     = ["connect"]
    available_actions   = []

    package_version = "0.0.3"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-server"
        tag        = "v0.2.0"
      }
    }]
  }

  rds_postgres_db_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-rds"
    repository_branch   = "v0.2.0"
    repository_ref_type = "tags"
    service_path        = "rds-postgres-db"
    service_name        = "RDS Postgres Database - Agustin Test"
    available_links     = ["connect"]
    available_actions   = []

    package_version = "0.0.3"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-db"
        tag        = "v0.2.0"
      }
    }]
  }

  aws_s3_bucket_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-s-3"
    repository_branch   = "v0.3.1"
    repository_ref_type = "tags"
    service_path        = "aws-s3-bucket"
    service_name        = "AWS S3 Bucket - Agent K8s"
    available_links     = ["connect"]
    available_actions   = []

    package_version = "0.0.3"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/s3"
        tag        = "v0.3.1"
      }
    }]
  }

  aws_dynamodb_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-dynamo-db"
    repository_branch   = "v0.3.0"
    repository_ref_type = "tags"
    service_path        = "dynamodb"
    service_name        = "AWS DynamoDB - Agustin Test"
    available_links     = ["connect", "trigger"]
    available_actions   = []

    package_version = "0.0.2"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/dynamo-db"
        tag        = "v0.3.0"
      }
    }]
  }

  # services-postgresql-k-8-s v1.0.1 is the first working release with the s3-aligned
  # layout (service under postgres-db/) and a worker image; the specs and the
  # code running in the worker come from the same tag.
  postgres_db_k8s_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-k-8-s"
    repository_branch   = "v1.0.1"
    repository_ref_type = "tags"
    service_path        = "postgres-db"
    service_name        = "Postgres DB K8s - Agustin Test"
    available_links     = ["database-user"]
    available_actions   = ["run-ddl-query", "run-dml-query"]

    package_version = "0.0.5"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/postgresql-k8s"
        tag        = "v1.0.1"
      }
    }]
  }

  service_definitions_catalog = {
    rds_postgres_server = local.rds_postgres_server_definition
    rds_postgres_db     = local.rds_postgres_db_definition
    aws_s3_bucket       = local.aws_s3_bucket_definition
    aws_dynamodb        = local.aws_dynamodb_definition
    postgres_db_k8s     = local.postgres_db_k8s_definition
  }

  # version (when provided) overrides the catalog branch; otherwise the catalog
  # branch is kept. The package artifact reference is NOT touched by the
  # override (see the catalog header).
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
