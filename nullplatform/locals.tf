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
  # every organization): by tag where the release registers one, by digest for
  # the scopes repository, which registers digests only. A tag re-registered
  # against a new image drifts to it on the next plan, by design.
  # Consequence: a `version` override from tfvars does NOT update the artifact
  # reference; versions are changed here, in the catalog.
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
        digest     = var.worker_image_digest # v1.15.1; scopes publishes no artifact for this tag
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
    # lookup reuses the artifact the containers package registers. The dedicated
    # scopes/scheduled-task image is not usable yet (wrong NP_SERVICE_PATH, no
    # aws-cli; fix in nullplatform/scopes); 0.0.3 pointed at it and was reverted.
    package_version = "0.0.4"
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

    package_version = "0.0.3"
    # Pinned by id to the artifact nullplatform registers on release. A lookup by
    # tag is blocked while our old digest-only artifact exists: the provider
    # prefers an owned artifact over the global one even when it has no
    # matching revision, and artifact deletion is a no-op in the provider.
    package_artifacts = [{
      name                 = "worker-image"
      type                 = "oci_image"
      resource_id          = "209834bd-f009-4ead-bfbe-047c32264927" # scopes-static-files v0.5.0, digest sha256:00cef1…
      resource_revision_id = "9eaab220-8b68-410c-b389-b65cb655ae1d"
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

    package_version = "0.0.4"
    # Pinned by id to the artifact nullplatform registers on release. A lookup by
    # tag is blocked while our old digest-only artifact exists: the provider
    # prefers an owned artifact over the global one even when it has no
    # matching revision, and artifact deletion is a no-op in the provider.
    package_artifacts = [{
      name                 = "worker-image"
      type                 = "oci_image"
      resource_id          = "49ec8214-dc2d-4e6e-96a7-84c38a4c3bee" # scopes-lambda v0.5.0
      resource_revision_id = "66013688-74ad-4fe4-9fc1-b77f396d01e1"
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
    # Pinned by id to the artifact nullplatform registers on release. A lookup by
    # tag is blocked while our old digest-only artifact exists: the provider
    # prefers an owned artifact over the global one even when it has no
    # matching revision, and artifact deletion is a no-op in the provider.
    package_artifacts = [{
      name                 = "worker-image"
      type                 = "oci_image"
      resource_id          = "005c7db5-7375-48f2-b3bc-4ffce50dc922" # services-postgresql-rds v0.2.0
      resource_revision_id = "ab00fcf6-1dee-4ac1-a45b-5c3c330f9d51"
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
    # Pinned by id to the artifact nullplatform registers on release. A lookup by
    # tag is blocked while our old digest-only artifact exists: the provider
    # prefers an owned artifact over the global one even when it has no
    # matching revision, and artifact deletion is a no-op in the provider.
    package_artifacts = [{
      name                 = "worker-image"
      type                 = "oci_image"
      resource_id          = "c31fed66-15fa-4d75-9321-6aea19eb1013" # services-postgresql-rds v0.2.0
      resource_revision_id = "4ebccab1-b98d-42cd-a724-94c3bca063c3"
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
    # Pinned by id to the artifact nullplatform registers on release. A lookup by
    # tag is blocked while our old digest-only artifact exists: the provider
    # prefers an owned artifact over the global one even when it has no
    # matching revision, and artifact deletion is a no-op in the provider.
    package_artifacts = [{
      name                 = "worker-image"
      type                 = "oci_image"
      resource_id          = "fa5b569c-80da-4d6c-836c-4fdb0670c67d" # services-s-3 v0.3.1
      resource_revision_id = "71694e3a-5637-4ba6-840e-2436c2eecb02"
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
