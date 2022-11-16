locals {
  module_name    = "bigquery-loader-pubsub-ce"
  module_version = "0.1.0"

  app_name    = "snowplow-bigquery-loader"
  app_version = "1.5.2"

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
  version = "0.3.0"

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

data "google_compute_image" "ubuntu_20_04" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
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
  name = "${var.name}-ssh-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_ip_allowlist
}

resource "google_compute_firewall" "egress" {
  name = "${var.name}-traffic-out"

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
          version                  = local.app_version
          require_partition_filter = var.bigquery_require_partition_filter
          partition_column         = var.bigquery_partition_column
          config_base64            = local.config_base64
          iglu_resolver_base64     = local.iglu_resolver_base64
          gcp_logs_enabled         = var.gcp_logs_enabled
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_1)
      })

      machine_type = var.machine_type_mutator
      target_size  = 1
    }

    repeater = {
      metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
        application_script = templatefile("${path.module}/templates/bq-repeater.sh.tmpl", {
          version              = local.app_version
          config_base64        = local.config_base64
          iglu_resolver_base64 = local.iglu_resolver_base64
          gcp_logs_enabled     = var.gcp_logs_enabled
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_2)
      })

      machine_type = var.machine_type_repeater
      target_size  = var.target_size_repeater
    }

    streamloader = {
      metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
        application_script = templatefile("${path.module}/templates/bq-streamloader.sh.tmpl", {
          version              = local.app_version
          config_base64        = local.config_base64
          iglu_resolver_base64 = local.iglu_resolver_base64
          gcp_logs_enabled     = var.gcp_logs_enabled
        })
        telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data_3)
      })

      machine_type = var.machine_type_streamloader
      target_size  = var.target_size_streamloader
    }
  }

  ssh_keys_metadata = <<EOF
%{for v in var.ssh_key_pairs~}
    ${v.user_name}:${v.public_key}
%{endfor~}
EOF
}

resource "google_compute_instance_template" "tpl" {
  for_each = local.applications

  name_prefix = "${var.name}-${each.key}-"
  description = "This template is used to create bigquery loader ${each.key} instances"

  instance_description = "${var.name}-${each.key}"
  machine_type         = each.value.machine_type

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = var.ubuntu_20_04_source_image == "" ? data.google_compute_image.ubuntu_20_04.self_link : var.ubuntu_20_04_source_image
    auto_delete  = true
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  # Note: Only one of either network or subnetwork can be supplied
  #       https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template#network_interface
  network_interface {
    network    = var.subnetwork == "" ? var.network : ""
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.associate_public_ip_address ? [1] : []

      content {
        network_tier = "PREMIUM"
      }
    }
  }

  service_account {
    email  = google_service_account.sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = each.value.metadata_startup_script

  metadata = {
    block-project-ssh-keys = var.ssh_block_project_keys

    ssh-keys = local.ssh_keys_metadata
  }

  tags = ["${var.name}-${each.key}"]

  labels = merge(
    local.labels,
    {
      app_project_name = each.key
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "grp" {
  for_each = local.applications

  name = "${var.name}-${each.key}-grp"

  base_instance_name = "${var.name}-${each.key}"
  region             = var.region

  target_size = each.value.target_size

  version {
    name              = "${local.app_name}-${each.key}-${local.app_version}"
    instance_template = google_compute_instance_template.tpl[each.key].self_link
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_unavailable_fixed = 3
  }

  wait_for_instances = true

  timeouts {
    create = "20m"
    update = "20m"
    delete = "30m"
  }
}
