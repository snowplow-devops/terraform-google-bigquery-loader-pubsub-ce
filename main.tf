locals {
  module_name    = "bigquery-loader-pubsub-ce"
  module_version = "0.3.2"

  app_name    = "snowplow-bigquery-loader"
  app_version = var.app_version

  local_labels = {
    name           = var.name
    app_name       = local.app_name
    app_version    = replace(local.app_version, ".", "-")
    module_name    = local.module_name
    module_version = replace(local.module_version, ".", "-")
  }

  labels = merge(
    var.labels,
    local.local_labels
  )
}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "GCP"
  region           = var.region
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version

  app_name_override_1 = "snowplow-bigquery-mutator"
  app_name_override_2 = "snowplow-bigquery-repeater"
  app_name_override_3 = "snowplow-bigquery-streamloader"
}

# --- IAM: Service Account setup

resource "google_service_account" "sa" {
  account_id   = var.name
  display_name = "Snowplow BQ Loader service account - ${var.name}"
}

resource "google_project_iam_member" "sa_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_logging_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_storage_bucket_iam_binding" "dead_letter_storage_object_admin_binding" {
  bucket = var.gcs_dead_letter_bucket_name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.sa.email}"
  ]
}

resource "google_bigquery_dataset_iam_member" "dataset_bigquery_data_editor_binding" {
  project    = var.project_id
  dataset_id = var.bigquery_dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.sa.email}"
}

# --- CE: Firewall rules

resource "google_compute_firewall" "ingress_ssh" {
  project = (var.network_project_id != "") ? var.network_project_id : var.project_id
  name    = "${var.name}-ssh-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_ip_allowlist
}

resource "google_compute_firewall" "egress" {
  project = (var.network_project_id != "") ? var.network_project_id : var.project_id
  name    = "${var.name}-traffic-out"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
}

# --- PubSub: Topics and subscriptions

resource "google_pubsub_topic" "types" {
  name   = "${var.name}-types-topic"
  labels = local.labels
}

resource "google_pubsub_topic" "failed_inserts" {
  name   = "${var.name}-failed-inserts-topic"
  labels = local.labels
}

resource "google_pubsub_subscription" "input" {
  name  = "${var.name}-input"
  topic = var.input_topic_name

  expiration_policy {
    ttl = ""
  }

  labels = local.labels
}

resource "google_pubsub_subscription" "types" {
  name  = "${var.name}-types"
  topic = google_pubsub_topic.types.name

  expiration_policy {
    ttl = ""
  }

  labels = local.labels
}

resource "google_pubsub_subscription" "failed_inserts" {
  name  = "${var.name}-failed-inserts"
  topic = google_pubsub_topic.failed_inserts.name

  expiration_policy {
    ttl = ""
  }

  labels = local.labels
}

# --- CE: Instance group setup

locals {
  resolvers_raw = concat(var.default_iglu_resolvers, var.custom_iglu_resolvers)

  resolvers_open = [
    for resolver in local.resolvers_raw : merge(
      {
        name           = resolver["name"],
        priority       = resolver["priority"],
        vendorPrefixes = resolver["vendor_prefixes"],
        connection = {
          http = {
            uri = resolver["uri"]
          }
        }
      }
    ) if resolver["api_key"] == ""
  ]

  resolvers_closed = [
    for resolver in local.resolvers_raw : merge(
      {
        name           = resolver["name"],
        priority       = resolver["priority"],
        vendorPrefixes = resolver["vendor_prefixes"],
        connection = {
          http = {
            uri    = resolver["uri"]
            apikey = resolver["api_key"]
          }
        }
      }
    ) if resolver["api_key"] != ""
  ]

  resolvers = flatten([
    local.resolvers_open,
    local.resolvers_closed
  ])

  iglu_resolver = templatefile("${path.module}/templates/iglu_resolver.json.tmpl", { resolvers = jsonencode(local.resolvers) })

  config = templatefile("${path.module}/templates/config.json.tmpl", {
    project_id = var.project_id

    # config: loader
    input_subscription_name   = google_pubsub_subscription.input.name
    dataset_id                = var.bigquery_dataset_id
    table_id                  = var.bigquery_table_id
    bad_rows_topic_name       = var.bad_rows_topic_name
    types_topic_name          = google_pubsub_topic.types.name
    failed_inserts_topic_name = google_pubsub_topic.failed_inserts.name

    # config: mutator
    types_sub_name = google_pubsub_subscription.types.name

    # config: repeater
    failed_inserts_sub_name     = google_pubsub_subscription.failed_inserts.name
    gcs_dead_letter_bucket_name = var.gcs_dead_letter_bucket_name
  })

  config_base64        = base64encode(local.config)
  iglu_resolver_base64 = base64encode(local.iglu_resolver)

  applications = {
    mutator = {
      metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
        application_script = templatefile("${path.module}/templates/bq-mutator.sh.tmpl", {
          accept_limited_use_license = var.accept_limited_use_license

          version                  = local.app_version
          require_partition_filter = var.bigquery_require_partition_filter
          partition_column         = var.bigquery_partition_column
          config_base64            = local.config_base64
          iglu_resolver_base64     = local.iglu_resolver_base64
          gcp_logs_enabled         = var.gcp_logs_enabled
          java_opts                = var.java_opts
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_1)
      })

      machine_type = var.machine_type_mutator
      target_size  = 1
    }

    repeater = {
      metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
        application_script = templatefile("${path.module}/templates/bq-repeater.sh.tmpl", {
          accept_limited_use_license = var.accept_limited_use_license

          version              = local.app_version
          config_base64        = local.config_base64
          iglu_resolver_base64 = local.iglu_resolver_base64
          gcp_logs_enabled     = var.gcp_logs_enabled
          java_opts            = var.java_opts
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_2)
      })

      machine_type = var.machine_type_repeater
      target_size  = var.target_size_repeater
    }

    streamloader = {
      metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
        application_script = templatefile("${path.module}/templates/bq-streamloader.sh.tmpl", {
          accept_limited_use_license = var.accept_limited_use_license

          version              = local.app_version
          config_base64        = local.config_base64
          iglu_resolver_base64 = local.iglu_resolver_base64
          gcp_logs_enabled     = var.gcp_logs_enabled
          java_opts            = var.java_opts
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_3)
      })

      machine_type = var.machine_type_streamloader
      target_size  = var.target_size_streamloader
    }
  }
}

module "service" {
  source  = "snowplow-devops/service-ce/google"
  version = "0.1.0"

  for_each = local.applications

  user_supplied_script        = each.value.metadata_startup_script
  name                        = "${var.name}-${each.key}"
  instance_group_version_name = "${local.app_name}-${local.app_version}"

  labels = merge(
    local.labels,
    {
      app_project_name = each.key
    }
  )

  region     = var.region
  network    = var.network
  subnetwork = var.subnetwork

  ubuntu_20_04_source_image   = var.ubuntu_20_04_source_image
  machine_type                = each.value.machine_type
  target_size                 = each.value.target_size
  ssh_block_project_keys      = var.ssh_block_project_keys
  ssh_key_pairs               = var.ssh_key_pairs
  service_account_email       = google_service_account.sa.email
  associate_public_ip_address = var.associate_public_ip_address
}
