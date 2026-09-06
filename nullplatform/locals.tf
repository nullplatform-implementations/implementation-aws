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
  # and must be bumped together with `version`, the worker image digest, or any
  # change to the action set - anything that alters the bill of materials.
  # package_artifacts are declared literally per entry because OCI and git
  # artifacts carry different `meta` shapes. Consequence: a `version` override
  # from tfvars does NOT update the artifact reference; versions are changed
  # here, in the catalog.
  ##############################################################################

  containers_definition = {
    service_spec_name          = "Containers"
    service_spec_description   = "Docker containers on pods"
    service_path               = "k8s"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.15.1"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    package_version = "0.0.1"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/containers"
        digest     = var.worker_image_digest # v1.15.1
      }
    }]
  }

  scheduled_tasks_definition = {
    service_spec_name          = "Scheduled Task"
    service_spec_description   = "Allows you to deploy periodic jobs in Kubernetes"
    service_path               = "scheduled_task"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.15.1"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    # Same image as containers: the scheduled task is the k8s scope with the
    # scheduled_task overlay, which the worker receives as NP_OVERRIDES_PATH.
    # lookup reuses the artifact the containers package registers.
    package_version = "0.0.2"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/containers"
        digest     = var.worker_image_digest # v1.15.1
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

    # Worker image published by the scopes-static-files release.
    package_version = "0.0.2"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/static-files"
        digest     = "sha256:00cef1dba2f91f99ffc5ab1849dc4fa18d6769cc544865e072a7fea8544df85d" # v0.5.0
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

    # Worker image published by the scopes-lambda release.
    package_version = "0.0.3"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/lambda"
        digest     = "sha256:a53b20894da567ff242815566503f8d653d821f51cde97654e597e40aad1c212" # v0.5.0
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

    package_version = "0.0.2"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-server"
        digest     = "sha256:55677841280a10d70d95fc28b784daff5d1e7158ff781df66ff1c3fae278e3c7" # v0.2.0
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

    package_version = "0.0.2"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-db"
        digest     = "sha256:ee22c80583794e7781361e7767f13c5cb196894ec77b164f43eef614bb8187c2" # v0.2.0
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

    # Worker image published by the services-s-3 release.
    package_version = "0.0.2"
    package_artifacts = [{
      name = "worker-image"
      type = "oci_image"
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/s3"
        digest     = "sha256:891ba116475760a230cd715b789d94bf7e186d0923c203addbbad6a489759b33" # v0.3.1
      }
    }]
  }

  aws_dynamodb_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-dynamo-db"
    repository_branch   = "v0.2.0"
    repository_ref_type = "tags"
    service_path        = "dynamodb"
    service_name        = "AWS DynamoDB - Agustin Test"
    available_links     = ["connect", "trigger"]
    available_actions   = []

    package_version = "0.0.1"
    package_artifacts = [{
      name = "impl"
      type = "git_repository"
      meta = {
        url       = "https://github.com/nullplatform/services-dynamo-db.git"
        reference = "v0.2.0"
      }
    }]
  }

  # services-postgresql-k-8-s publishes no tags, so this is pinned to a commit
  # SHA (HEAD of main on 2026-09-03) with repository_ref_type = "" - the module
  # then reads raw.githubusercontent.com/<org>/<repo>/<sha>/... directly.
  # Replace with a tag as soon as upstream publishes one. Note the agent in
  # infrastructure/aws still clones the proposal/align-with-services-s-3 branch
  # for this repo; the two are not in lockstep today.
  postgres_db_k8s_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-k-8-s"
    repository_branch   = "1118803b7afd44fa4eb00fd23179a5bd07bd4e6c"
    repository_ref_type = ""
    service_path        = "postgres/k8s"
    service_name        = "Postgres DB K8s - Agustin Test"
    available_links     = ["database-user"]
    available_actions   = ["run-ddl-query", "run-dml-query"]

    package_version = "0.0.1"
    package_artifacts = [{
      name = "impl"
      type = "git_repository"
      meta = {
        url       = "https://github.com/nullplatform/services-postgresql-k-8-s.git"
        reference = "1118803b7afd44fa4eb00fd23179a5bd07bd4e6c"
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
