locals {
  module_name    = "bigquery-loader-pubsub-ce"
  module_version = "0.3.1"

  app_name     = "snowplow-bigquery-loader"
  app_version  = var.app_version
  ingress_port = 8000

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

resource "google_bigquery_dataset_iam_member" "dataset_bigquery_data_editor_binding" {
  project    = var.project_id
  dataset_id = var.bigquery_dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.sa.email}"
}

# --- CE: Firewall rules

resource "google_compute_firewall" "ingress_health_check" {
  count = var.healthcheck_enabled == true ? 1 : 0
  name  = "${var.name}-traffic-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["${local.ingress_port}"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

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

resource "google_pubsub_subscription" "input" {
  name  = "${var.name}-input"
  topic = var.input_topic_name

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

  iglu_resolver = templatefile("${path.module}/templates/iglu_resolver.json.tmpl", {
    resolvers  = jsonencode(local.resolvers)
    cache_size = var.iglu_cache_size
    cache_ttl  = var.iglu_cache_ttl_seconds
  })

  hocon = templatefile("${path.module}/templates/config.json.tmpl", {
    project_id                        = var.project_id
    input_subscription_id             = google_pubsub_subscription.input.id
    dataset_id                        = var.bigquery_dataset_id
    table_id                          = var.bigquery_table_id
    bad_rows_topic_id                 = var.bad_rows_topic_id
    bigquery_service_account_json_b64 = var.bigquery_service_account_json_b64

    skip_schemas      = jsonencode(var.skip_schemas)
    legacy_columns    = jsonencode(var.legacy_columns)
    webhook_collector = var.webhook_collector
    tags              = jsonencode(var.labels)

    telemetry_disable          = !var.telemetry_enabled
    telemetry_collector_uri    = join("", module.telemetry.*.collector_uri)
    telemetry_collector_port   = 443
    telemetry_secure           = true
    telemetry_user_provided_id = var.user_provided_id
    telemetry_auto_gen_id      = join("", module.telemetry.*.auto_generated_id)
    telemetry_module_name      = local.module_name
    telemetry_module_version   = local.module_version
  })

  startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
    version                           = local.app_version
    config_b64                        = base64encode(local.hocon)
    iglu_config_b64                   = base64encode(local.iglu_resolver)
    accept_limited_use_license        = var.accept_limited_use_license
    bigquery_service_account_json_b64 = base64decode(var.bigquery_service_account_json_b64)
    telemetry_script                  = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data)
    gcp_logs_enabled                  = var.gcp_logs_enabled
    java_opts                         = var.java_opts
  })
}

module "service" {
  source  = "snowplow-devops/service-ce/google"
  version = "0.1.0"

  user_supplied_script        = local.startup_script
  name                        = var.name
  instance_group_version_name = "${local.app_name}-${local.app_version}"

  labels = local.labels

  region     = var.region
  network    = var.network
  subnetwork = var.subnetwork

  ubuntu_20_04_source_image   = var.ubuntu_20_04_source_image
  machine_type                = var.machine_type
  target_size                 = var.target_size
  ssh_block_project_keys      = var.ssh_block_project_keys
  ssh_key_pairs               = var.ssh_key_pairs
  service_account_email       = google_service_account.sa.email
  associate_public_ip_address = var.associate_public_ip_address

  named_port_http   = var.healthcheck_enabled == true ? "http" : ""
  ingress_port      = var.healthcheck_enabled == true ? local.ingress_port : -1
  health_check_path = var.healthcheck_enabled == true ? "/" : ""
}
