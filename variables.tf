variable "accept_limited_use_license" {
  description = "Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/)"
  type        = bool
  default     = false

  validation {
    condition     = var.accept_limited_use_license
    error_message = "Please accept the terms of the Snowplow Limited Use License Agreement to proceed."
  }
}

variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

//TODO still RC, wait for proper release
variable "app_version" {
  description = "App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value."
  type        = string
  default     = "2.0.0-rc10"
}

variable "project_id" {
  description = "The project ID in which the stack is being deployed"
  type        = string
}

variable "network_project_id" {
  description = "The project ID of the shared VPC in which the stack is being deployed"
  type        = string
  default     = ""
}

variable "region" {
  description = "The name of the region to deploy within"
  type        = string
}

variable "network" {
  description = "The name of the network to deploy within"
  type        = string
}

variable "subnetwork" {
  description = "The name of the sub-network to deploy within; if populated will override the 'network' setting"
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance; if false this instance must be behind a Cloud NAT to connect to the internet"
  type        = bool
  default     = true
}

variable "ssh_ip_allowlist" {
  description = "The list of CIDR ranges to allow SSH traffic from"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "ssh_block_project_keys" {
  description = "Whether to block project wide SSH keys"
  type        = bool
  default     = true
}

variable "ssh_key_pairs" {
  description = "The list of SSH key-pairs to add to the servers"
  default     = []
  type = list(object({
    user_name  = string
    public_key = string
  }))
}

variable "ubuntu_20_04_source_image" {
  description = "The source image to use which must be based of of Ubuntu 20.04; by default the latest community version is used"
  default     = ""
  type        = string
}

variable "labels" {
  description = "The labels to append to this resource"
  default     = {}
  type        = map(string)
}

variable "gcp_logs_enabled" {
  description = "Whether application logs should be reported to GCP Logging"
  default     = true
  type        = bool
}

variable "java_opts" {
  description = "Custom JAVA Options"
  default     = "-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"
  type        = string
}

# --- Configuration options

variable "machine_type" {
  description = "The machine type to use"
  type        = string
  default     = "e2-small"
}

variable "target_size" {
  description = "The number of servers to deploy"
  default     = 1
  type        = number
}

variable "input_topic_name" {
  description = "The name of the input topic that contains enriched data to load"
  type        = string
}

variable "bad_rows_topic_id" {
  description = "The id of the output topic for all bad data"
  type        = string
}

variable "bigquery_dataset_id" {
  description = "The ID of the bigquery dataset to load data into"
  type        = string
}

variable "bigquery_table_id" {
  description = "The ID of the table within a dataset to load data into (will be created if it doesn't exist)"
  default     = "events"
  type        = string
}

variable "bigquery_service_account_json_b64" {
  description = "Custom credentials (as base64 encoded service account key) instead of default service account assigned to the loader's compute group"
  default     = ""
  type        = string
}
# --- Iglu Resolver

variable "default_iglu_resolvers" {
  description = "The default Iglu Resolvers that will be used by the loader to resolve and validate events"
  default = [
    {
      name            = "Iglu Central"
      priority        = 10
      uri             = "http://iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    },
    {
      name            = "Iglu Central - Mirror 01"
      priority        = 20
      uri             = "http://mirror01.iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    }
  ]
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

variable "custom_iglu_resolvers" {
  description = "The custom Iglu Resolvers that will be used by the loader to resolve and validate events"
  default     = []
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

variable "iglu_cache_size" {
  description = "The size of cache used by Iglu Resolvers"
  type        = number
  default     = 500
}

variable "iglu_cache_ttl_seconds" {
  description = "Duration in seconds, how long should entries be kept in Iglu Resolvers cache before they expire"
  type        = number
  default     = 600
}

# --- Telemetry

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}

# --- Webhook monitoring

variable "webhook_collector" {
  description = "Collector address used to gather monitoring alerts"
  type        = string
  default     = ""
}

variable "skip_schemas" {
  description = "The list of schema keys which should be skipped (not loaded) to the warehouse"
  type        = list(string)
  default     = []
}

variable "legacy_columns" {
  description = "Schemas for which to use the legacy column style used by the v1 BigQuery Loader. For these columns, there is a column per _minor_ version of each schema."
  type        = list(string)
  default     = []
}

variable "healthcheck_enabled" {
  description = "Whether or not to enable health check probe for GCP instance group"
  type        = bool
  default     = true
}

variable "exit_on_missing_iglu_schema" {
  description = "Whether the loader should crash and exit if it fails to resolve an iglu schema"
  type        = bool
  default     = true
}

variable "legacy_column_mode" {
  description = "Whether the loader should load to legacy columns for all fields"
  type        = bool
  default     = false
}
