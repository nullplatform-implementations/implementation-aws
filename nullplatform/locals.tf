locals {
  # The catalog has two halves, one per verb:
  #   - published_*: specifications this organization maintains and publishes
  #     as its own packages (scope_definition / service_definition);
  #   - installed_*: packages someone published (nullplatform, another
  #     organization, or this one) that this organization installs at a pinned
  #     version (scope_package_installation / package_installation).
  # An entry appears in both when the organization installs what it publishes.
  #
  # Published scopes; per-environment toggles live in var.published_scopes and
  # are merged below. Two rules:
  #   - version must match the requirements module ref in infrastructure/aws
  #     (a mismatch only shows up at deploy time, never at plan time)
  #   - package_version is the revision published here: bump it with any change
  #     to version, actions or artifacts, and change tags in this catalog
  #     (a version override from tfvars does not move the artifact tag)

  containers_definition = {
    service_spec_name          = "Containers"
    service_spec_description   = "Docker containers on pods"
    service_path               = "k8s"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.20.0"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    package_version = "0.0.6"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/containers"
        tag        = "v1.20.0"
      }
    }]
  }

  scheduled_tasks_definition = {
    service_spec_name          = "Scheduled Task"
    service_spec_description   = "Allows you to deploy periodic jobs in Kubernetes"
    service_path               = "scheduled_task"
    repository_org             = "nullplatform"
    repository_name            = "scopes"
    version                    = "v1.20.0"
    repository_ref_type        = "tags"
    create_scope_configuration = false

    package_version = "0.0.6"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/scheduled-task"
        tag        = "v1.20.0"
      }
    }]
  }

  static_files_definition = {
    service_spec_name          = "Static Scope"
    service_spec_description   = "Allows you to deploy static to S3"
    service_path               = "static-files"
    repository_org             = "nullplatform"
    repository_name            = "scopes-static-files"
    version                    = "v4.2.0"
    repository_ref_type        = "tags"
    create_scope_configuration = true

    package_version = "4.2.0"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/scopes/static-files"
        tag        = "v4.2.0"
      }
    }]
  }

  mobile_store_definition = {
    service_spec_name          = "Mobile store"
    service_spec_description   = "Publishes mobile app binaries to distribution channels"
    service_path               = "mobile-store"
    repository_org             = "nullplatform"
    repository_name            = "scopes-mobile-store"
    version                    = "v0.5.3"
    repository_ref_type        = "tags"
    create_scope_configuration = true

    # Must match worker_orchestrated_packages (infrastructure/aws) and the
    # "mobile-store" IAM selector (nullplatform-bindings).
    package_slug    = "mobile-store"
    package_version = "0.2.1"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/agent-plugins/scopes/mobile-store"
        tag        = "v0.5.3"
      }
    }]
  }

  voltmx_foundry_app_definition = {
    service_spec_name          = "Volt MX Foundry app"
    service_spec_description   = "Publishes a Volt MX Foundry app to a Foundry environment"
    service_path               = "voltmx-foundry-app"
    repository_org             = "nullplatform"
    repository_name            = "scopes-voltmx-foundry-app"
    version                    = "v0.1.5"
    repository_ref_type        = "tags"
    create_scope_configuration = true

    # Must match worker_orchestrated_packages (infrastructure/aws) and the
    # "voltmx-foundry-app" IAM selector (nullplatform-bindings).
    package_slug    = "voltmx-foundry-app"
    package_version = "0.1.5"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/agent-plugins/scopes/voltmx-foundry-app"
        tag        = "v0.1.5"
      }
    }]
  }

  published_scopes = {
    containers         = local.containers_definition
    scheduled_tasks    = local.scheduled_tasks_definition
    static_files       = local.static_files_definition
    mobile_store       = local.mobile_store_definition
    voltmx_foundry_app = local.voltmx_foundry_app_definition
  }

  # Catalog + per-environment overrides, keeping only the entries toggled on.
  published_scopes_enabled = {
    for k, v in local.published_scopes : k => merge(v, {
      version        = coalesce(try(var.published_scopes[k].version, null), v.version)
      repository_url = "https://raw.githubusercontent.com/${v.repository_org}/${v.repository_name}/refs/${v.repository_ref_type}"

      repository_service_spec             = try(var.published_scopes[k].repository_service_spec, null)
      repository_service_spec_version     = try(var.published_scopes[k].repository_service_spec_version, null)
      repository_scope_template           = try(var.published_scopes[k].repository_scope_template, null)
      repository_scope_template_version   = try(var.published_scopes[k].repository_scope_template_version, null)
      repository_action_templates         = try(var.published_scopes[k].repository_action_templates, null)
      repository_action_templates_version = try(var.published_scopes[k].repository_action_templates_version, null)
    })
    if try(var.published_scopes[k].enabled, true)
  }

  # Installed scopes. The package brings the specification and its actions,
  # read-only; the organization owns what it creates on top of them (the scope
  # type, the NRN settings and the scope-configuration schema), rendered from
  # the templates of the repository the package is published from, at the tag
  # of the installed version (v<version>: packages are versioned by their
  # release tag).
  installed_scopes = {
    # nullplatform's Lambda scope. The np- prefix keeps it apart from copies
    # an organization registered under aws-lambda / lambda.
    aws_lambda_global = {
      package = {
        slug    = "np-aws-lambda"
        version = "0.13.3"
      }
      repository_org             = "nullplatform"
      repository_name            = "scopes-lambda"
      repository_ref_type        = "tags"
      service_spec_name          = "AWS Lambda"
      service_spec_description   = "Serverless functions on AWS Lambda"
      service_path               = "lambda"
      create_scope_configuration = true
    }
    # nullplatform's Kubernetes scopes, from the scopes monorepo: three packages
    # published at the same tag. Names carry "(nullplatform)" because the
    # account also runs its own copies ("Containers", "Scheduled Task").
    containers_global = {
      package = {
        slug    = "np-containers"
        version = "1.21.0"
      }
      repository_org             = "nullplatform"
      repository_name            = "scopes"
      repository_ref_type        = "tags"
      service_spec_name          = "Containers (nullplatform)"
      service_spec_description   = "Docker containers on pods"
      service_path               = "k8s"
      create_scope_configuration = false
    }
    containers_on_premise_global = {
      package = {
        slug    = "np-containers-on-premise"
        version = "1.21.0"
      }
      repository_org           = "nullplatform"
      repository_name          = "scopes"
      repository_ref_type      = "tags"
      service_spec_name        = "Containers On-Premise (nullplatform)"
      service_spec_description = "Docker containers on pods, in on-premise clusters"
      service_path             = "onprem"
      # The scope configuration (the zone the cluster serves) is the organization's.
      create_scope_configuration = true
      # The template's name would collide with the schemas of the on-premise
      # copies the account already has.
      scope_configuration_name_override = "Containers On-Premise (nullplatform)"
    }
    scheduled_task_global = {
      package = {
        slug    = "np-scheduled-task"
        version = "1.21.0"
      }
      repository_org             = "nullplatform"
      repository_name            = "scopes"
      repository_ref_type        = "tags"
      service_spec_name          = "Scheduled Task (nullplatform)"
      service_spec_description   = "Allows you to deploy periodic jobs in Kubernetes"
      service_path               = "scheduled_task"
      create_scope_configuration = false
    }
  }

  # var.installed_scopes toggles an entry and may pin another package version.
  installed_scopes_enabled = {
    for k, v in local.installed_scopes : k => merge(v, {
      package = merge(v.package, {
        version = coalesce(try(var.installed_scopes[k].version, null), v.package.version)
      })
      version        = "v${coalesce(try(var.installed_scopes[k].version, null), v.package.version)}"
      repository_url = "https://raw.githubusercontent.com/${v.repository_org}/${v.repository_name}/refs/${v.repository_ref_type}"
    })
    if try(var.installed_scopes[k].enabled, true)
  }

  # Published services. Same package rules as the published scopes above.
  # repository_branch must be immutable: a tag with repository_ref_type = "tags"
  # or a SHA with "" (the module rejects main/master/head/latest).

  # Both RDS services live in services-postgresql-rds, one worker image each.
  rds_postgres_server_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-rds"
    repository_branch   = "v0.6.5"
    repository_ref_type = "tags"
    service_path        = "rds-postgres-server"
    service_name        = "RDS Postgres Server - Agustin Test"
    available_links     = ["connect"]
    available_actions   = []

    package_version = "0.0.4"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-server"
        tag        = "v0.6.5"
      }
    }]
  }

  rds_postgres_db_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-rds"
    repository_branch   = "v0.6.5"
    repository_ref_type = "tags"
    service_path        = "rds-postgres-db"
    service_name        = "RDS Postgres Database - Agustin Test"
    available_links     = ["connect"]
    available_actions   = []

    package_version = "0.0.4"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/rds-postgres-db"
        tag        = "v0.6.5"
      }
    }]
  }

  aws_dynamodb_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-dynamo-db"
    repository_branch   = "v0.6.3"
    repository_ref_type = "tags"
    service_path        = "dynamodb"
    service_name        = "AWS DynamoDB - Agustin Test"
    available_links     = ["connect", "trigger"]
    available_actions   = []

    package_version = "0.0.3"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/dynamo-db"
        tag        = "v0.6.3"
      }
    }]
  }

  # v1.0.2 is the first release with the s3-aligned layout (service under
  # postgres-db/) and a worker image.
  postgres_db_k8s_definition = {
    repository_org      = "nullplatform"
    repository_name     = "services-postgresql-k-8-s"
    repository_branch   = "v1.2.5"
    repository_ref_type = "tags"
    service_path        = "postgres-db"
    service_name        = "Postgres DB K8s - Agustin Test"
    available_links     = ["database-user"]
    available_actions   = ["run-ddl-query", "run-dml-query"]

    package_version = "0.0.7"
    package_artifacts = [{
      name   = "worker-image"
      type   = "oci_image"
      lookup = true
      meta = {
        registry   = "public.ecr.aws"
        repository = "nullplatform/services/postgresql-k8s"
        tag        = "v1.2.5"
      }
    }]
  }

  published_services = {
    rds_postgres_server = local.rds_postgres_server_definition
    rds_postgres_db     = local.rds_postgres_db_definition
    aws_dynamodb        = local.aws_dynamodb_definition
    postgres_db_k8s     = local.postgres_db_k8s_definition
  }

  # version overrides the catalog branch, but not the artifact reference.
  published_services_enabled = {
    for k, v in local.published_services : k => merge(v, {
      repository_branch = coalesce(try(var.published_services[k].version, null), v.repository_branch)
    })
    if try(var.published_services[k].enabled, true)
  }

  # Installed services. For a service the installation is the whole
  # nullplatform side; the channel stays in nullplatform-bindings. The
  # repository fields only describe where the package is published from.
  installed_services = {
    # nullplatform's S3 bucket service (specification "AWS S3 Bucket").
    aws_s3_bucket_global = {
      package = {
        slug    = "np-aws-s3-bucket"
        version = "0.6.1"
      }
      repository_org  = "nullplatform"
      repository_name = "services-s-3"
      service_path    = "aws-s3-bucket"
    }
    # nullplatform's SNS topic service (specification "AWS SNS").
    aws_sns_global = {
      package = {
        slug    = "np-aws-sns"
        version = "1.1.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-aws-sns"
      service_path    = "sns"
    }
    # nullplatform's SQS queue service (specification "AWS SQS").
    aws_sqs_global = {
      package = {
        slug    = "np-aws-sqs"
        version = "1.1.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-aws-sqs"
      service_path    = "sqs"
    }
    # nullplatform's DynamoDB table service (specification "AWS DynamoDB"). The
    # registered copy aws-dynamodb-agustin-test keeps running next to it.
    aws_dynamodb_global = {
      package = {
        slug    = "np-aws-dynamodb"
        version = "0.7.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-dynamo-db"
      service_path    = "dynamodb"
    }
    # nullplatform's ElastiCache Serverless Valkey service (specification "Serverless Valkey").
    serverless_valkey_global = {
      package = {
        slug    = "np-serverless-valkey"
        version = "0.7.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-valkey"
      service_path    = "valkey"
    }
    # nullplatform's in-cluster PostgreSQL service (specification "Postgres DB"),
    # a Helm release per instance on this cluster.
    postgres_db_global = {
      package = {
        slug    = "np-postgres-db"
        version = "1.3.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-postgresql-k-8-s"
      service_path    = "postgres-db"
    }
    # nullplatform's Endpoint Exposer (specification "Endpoint Exposer"): Istio
    # routes on the public and private gateways towards Containers scopes. Its
    # repository keeps the specs at the root.
    endpoint_exposer_global = {
      package = {
        slug    = "np-http-route-access-control"
        version = "2.2.0"
      }
      repository_org  = "nullplatform"
      repository_name = "services-endpoint-exposer"
      service_path    = ""
    }
  }

  # var.installed_services toggles an entry and may pin another package version.
  installed_services_enabled = {
    for k, v in local.installed_services : k => merge(v, {
      package = merge(v.package, {
        version = coalesce(try(var.installed_services[k].version, null), v.package.version)
      })
      repository_branch = "v${coalesce(try(var.installed_services[k].version, null), v.package.version)}"
    })
    if try(var.installed_services[k].enabled, true)
  }

  ##############################################################################
  # Dimensions catalog
  ##############################################################################

  dimensions_catalog = {
    environment = { name = "Environment", order = 1, values = ["development", "staging", "production"] }
    region      = { name = "Region", order = 2, values = ["us-east-1", "us-west-1"] }
    cloud       = { name = "Cloud", order = 3, values = ["ORACLE", "GCP"] }
  }

  # Per-environment overrides: 'enabled' toggles it, 'values' replaces the list.
  dimensions_enabled = {
    for k, v in local.dimensions_catalog : k => merge(v, {
      values = coalesce(try(var.dimensions[k].values, null), v.values)
    })
    if try(var.dimensions[k].enabled, true)
  }
}
