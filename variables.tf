variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

variable "project_id" {
  description = "The id of the project in which this resource is created"
  type        = string
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

# --- Configuration options

variable "machine_type_mutator" {
  description = "The machine type to use"
  type        = string
  default     = "e2-small"
}

variable "machine_type_repeater" {
  description = "The machine type to use"
  type        = string
  default     = "e2-small"
}

variable "target_size_repeater" {
  description = "The number of servers to deploy"
  default     = 1
  type        = number
}

variable "machine_type_streamloader" {
  description = "The machine type to use"
  type        = string
  default     = "e2-small"
}

variable "target_size_streamloader" {
  description = "The number of servers to deploy"
  default     = 1
  type        = number
}

variable "input_topic_name" {
  description = "The name of the input topic that contains enriched data to load"
  type        = string
}

variable "bad_rows_topic_name" {
  description = "The name of the output topic for all bad data"
  type        = string
}

variable "gcs_dead_letter_bucket_name" {
  description = "The name of the GCS bucket to dump unloadable events into"
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

variable "bigquery_require_partition_filter" {
  description = "Whether to require a filter on the partition column in all queries"
  default     = true
  type        = bool
}

variable "bigquery_partition_column" {
  description = "The partition column to use in the dataset"
  default     = "collector_tstamp"
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
