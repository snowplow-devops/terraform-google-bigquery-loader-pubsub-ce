[![Release][release-image]][release] [![CI][ci-image]][ci] [![License][license-image]][license] [![Registry][registry-image]][registry] [![Source][source-image]][source]

# terraform-google-bigquery-loader-pubsub-ce

A Terraform module which deploys the BigQuery Loader application on Google running on top of Compute Engine.  If you want to use a custom image for this deployment you will need to ensure it is based on top of Ubuntu 20.04.

## Telemetry

This module by default collects and forwards telemetry information to Snowplow to understand how our applications are being used.  No identifying information about your sub-account or account fingerprints are ever forwarded to us - it is very simple information about what modules and applications are deployed and active.

If you wish to subscribe to our mailing list for updates to these modules or security advisories please set the `user_provided_id` variable to include a valid email address which we can reach you at.

### How do I disable it?

To disable telemetry simply set variable `telemetry_enabled = false`.

### What are you collecting?

For details on what information is collected please see this module: https://github.com/snowplow-devops/terraform-snowplow-telemetry

## Usage

The BigQuery Loader reads data from a Snowplow Enriched output PubSub topic and writes in realtime to BigQuery events table.

```hcl
# NOTE: Needs to be fed by the enrich module with valid Snowplow Events
module "enriched_topic" {
  source  = "snowplow-devops/pubsub-topic/google"
  version = "0.3.0"

  name = "enriched-topic"
}

module "bad_rows_topic" {
  source  = "snowplow-devops/pubsub-topic/google"
  version = "0.3.0"

  name = "bad-rows-topic"
}

resource "google_bigquery_dataset" "pipeline_db" {
  dataset_id = "pipeline_db"
  location   = var.region
}

module "bigquery_loader_pubsub" {
  source  = "snowplow-devops/bigquery-loader-pubsub-ce/google"

  accept_limited_use_license = true

  name       = "bq-loader-server"
  project_id = var.project_id

  network    = var.network
  subnetwork = var.subnetwork
  region     = var.region

  input_topic_name            = module.enriched_topic.name
  bad_rows_topic_name         = module.bad_rows_topic.name
  bigquery_dataset_id         = google_bigquery_dataset.pipeline_db.dataset_id

  ssh_key_pairs    = []
  ssh_ip_allowlist = ["0.0.0.0/0"]

  # Linking in the custom Iglu Server here
  custom_iglu_resolvers = [
    {
      name            = "Iglu Server"
      priority        = 0
      uri             = "http://your-iglu-server-endpoint/api"
      api_key         = var.iglu_super_api_key
      vendor_prefixes = []
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.44.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 3.44.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_service"></a> [service](#module\_service) | snowplow-devops/service-ce/google | 0.1.0 |
| <a name="module_telemetry"></a> [telemetry](#module\_telemetry) | snowplow-devops/telemetry/snowplow | 0.5.0 |

## Resources

| Name | Type |
|------|------|
| [google_bigquery_dataset_iam_member.dataset_bigquery_data_editor_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset_iam_member) | resource |
| [google_compute_firewall.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_project_iam_member.sa_bigquery_data_editor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_logging_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_pubsub_subscriber](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_pubsub_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_pubsub_subscription.input](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_service_account.sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bad_rows_topic_name"></a> [bad\_rows\_topic\_name](#input\_bad\_rows\_topic\_name) | The name of the output topic for all bad data | `string` | n/a | yes |
| <a name="input_bigquery_dataset_id"></a> [bigquery\_dataset\_id](#input\_bigquery\_dataset\_id) | The ID of the bigquery dataset to load data into | `string` | n/a | yes |
| <a name="input_gcs_dead_letter_bucket_name"></a> [gcs\_dead\_letter\_bucket\_name](#input\_gcs\_dead\_letter\_bucket\_name) | The name of the GCS bucket to dump unloadable events into | `string` | n/a | yes |
| <a name="input_input_topic_name"></a> [input\_topic\_name](#input\_input\_topic\_name) | The name of the input topic that contains enriched data to load | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | A name which will be pre-pended to the resources created | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | The name of the network to deploy within | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The project ID in which the stack is being deployed | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The name of the region to deploy within | `string` | n/a | yes |
| <a name="input_accept_limited_use_license"></a> [accept\_limited\_use\_license](#input\_accept\_limited\_use\_license) | Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/) | `bool` | `false` | no |
| <a name="input_app_version"></a> [app\_version](#input\_app\_version) | App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value. | `string` | `"1.7.0"` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public ip address to this instance; if false this instance must be behind a Cloud NAT to connect to the internet | `bool` | `true` | no |
| <a name="input_bigquery_partition_column"></a> [bigquery\_partition\_column](#input\_bigquery\_partition\_column) | The partition column to use in the dataset | `string` | `"collector_tstamp"` | no |
| <a name="input_bigquery_require_partition_filter"></a> [bigquery\_require\_partition\_filter](#input\_bigquery\_require\_partition\_filter) | Whether to require a filter on the partition column in all queries | `bool` | `true` | no |
| <a name="input_bigquery_table_id"></a> [bigquery\_table\_id](#input\_bigquery\_table\_id) | The ID of the table within a dataset to load data into (will be created if it doesn't exist) | `string` | `"events"` | no |
| <a name="input_service_account_json_b64"></a> [bigquery\_service\_account\_json\_b64](#input\_bigquery\_service\_account\_json\_b64) | Custom credentials (as base64 encoded service account key) instead of default service account assigned to the loader's compute group | `string` | `""` | no |
| <a name="input_custom_iglu_resolvers"></a> [custom\_iglu\_resolvers](#input\_custom\_iglu\_resolvers) | The custom Iglu Resolvers that will be used by the loader to resolve and validate events | <pre>list(object({<br>    name            = string<br>    priority        = number<br>    uri             = string<br>    api_key         = string<br>    vendor_prefixes = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_default_iglu_resolvers"></a> [default\_iglu\_resolvers](#input\_default\_iglu\_resolvers) | The default Iglu Resolvers that will be used by the loader to resolve and validate events | <pre>list(object({<br>    name            = string<br>    priority        = number<br>    uri             = string<br>    api_key         = string<br>    vendor_prefixes = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "api_key": "",<br>    "name": "Iglu Central",<br>    "priority": 10,<br>    "uri": "http://iglucentral.com",<br>    "vendor_prefixes": []<br>  },<br>  {<br>    "api_key": "",<br>    "name": "Iglu Central - Mirror 01",<br>    "priority": 20,<br>    "uri": "http://mirror01.iglucentral.com",<br>    "vendor_prefixes": []<br>  }<br>]</pre> | no |
| <a name="input_iglu_cache_size"></a> [iglu\_cache\_size](#input\_iglu\_cache\_size) | The size of cache used by Iglu Resolvers | `number` | `500` | no |
| <a name="input_iglu_cache_ttl_seconds"></a> [iglu\_cache\_ttl\_seconds](#input\_iglu\_cache\_ttl\_seconds) | Duration in seconds, how long should entries be kept in Iglu Resolvers cache before they expire | `number` | `600` | no |
| <a name="input_java_opts"></a> [java\_opts](#input\_java\_opts) | Custom JAVA Options | `string` | `"-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | The labels to append to this resource | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use | `string` | `"e2-small"` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | The project ID of the shared VPC in which the stack is being deployed | `string` | `""` | no |
| <a name="input_ssh_block_project_keys"></a> [ssh\_block\_project\_keys](#input\_ssh\_block\_project\_keys) | Whether to block project wide SSH keys | `bool` | `true` | no |
| <a name="input_ssh_ip_allowlist"></a> [ssh\_ip\_allowlist](#input\_ssh\_ip\_allowlist) | The list of CIDR ranges to allow SSH traffic from | `list(any)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_ssh_key_pairs"></a> [ssh\_key\_pairs](#input\_ssh\_key\_pairs) | The list of SSH key-pairs to add to the servers | <pre>list(object({<br>    user_name  = string<br>    public_key = string<br>  }))</pre> | `[]` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The name of the sub-network to deploy within; if populated will override the 'network' setting | `string` | `""` | no |
| <a name="input_target_size"></a> [target\_size](#input\_target\_size) | The number of servers to deploy | `number` | `1` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Whether or not to send telemetry information back to Snowplow Analytics Ltd | `bool` | `true` | no |
| <a name="input_ubuntu_20_04_source_image"></a> [ubuntu\_20\_04\_source\_image](#input\_ubuntu\_20\_04\_source\_image) | The source image to use which must be based of of Ubuntu 20.04; by default the latest community version is used | `string` | `""` | no |
| <a name="input_user_provided_id"></a> [user\_provided\_id](#input\_user\_provided\_id) | An optional unique identifier to identify the telemetry events emitted by this stack | `string` | `""` | no |
| <a name="input_webhook_collector"></a> [webhook\_collector](#input\_webhook\_collector) | Collector address used to gather monitoring alerts | `string` | `""` | no |
| <a name="input_skip_schemas"></a> [skip\_schemas](#input\_skip\_schemas) | The list of schema keys which should be skipped (not loaded) to the warehouse | `list(string)` | `[]` | no |
| <a name="input_legacy_columns"></a> [legacy\_columns](#input\_legacy\_columns) | Schemas for which to use the legacy column style used by the v1 BigQuery Loader. For these columns, there is a column per _minor_ version of each schema. | `list(string)` | `[]` | no |
| <a name="input_healthcheck_enabled"></a> [healthcheck\_enabled](#input\_healthcheck\_enabled) | Whether or not to enable health check probe for GCP instance group | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_check_id"></a> [health\_check\_id](#output\_health\_check\_id) | Identifier for the health check on the instance group |
| <a name="output_health_check_self_link"></a> [health\_check\_self\_link](#output\_health\_check\_self\_link) | The URL for the health check on the instance group |
| <a name="output_instance_group_url"></a> [instance\_group\_url](#output\_instance\_group\_url) | The full URL of the instance group created by the manager |
| <a name="output_manager_id"></a> [manager\_id](#output\_manager\_id) | Identifier for the instance group manager |
| <a name="output_manager_self_link"></a> [manager\_self\_link](#output\_manager\_self\_link) | The URL for the instance group manager |
| <a name="output_named_port_http"></a> [named\_port\_http](#output\_named\_port\_http) | The name of the port exposed by the instance group |
| <a name="output_named_port_value"></a> [named\_port\_value](#output\_named\_port\_value) | The named port value (e.g. 8080) |

# Copyright and license

Copyright 2022-present Snowplow Analytics Ltd.

Licensed under the [Snowplow Limited Use License Agreement][license]. _(If you are uncertain how it applies to your use case, check our answers to [frequently asked questions][license-faq].)_

[release]: https://github.com/snowplow-devops/terraform-google-bigquery-loader-pubsub-ce/releases/latest
[release-image]: https://img.shields.io/github/v/release/snowplow-devops/terraform-google-bigquery-loader-pubsub-ce

[ci]: https://github.com/snowplow-devops/terraform-google-bigquery-loader-pubsub-ce/actions?query=workflow%3Aci
[ci-image]: https://github.com/snowplow-devops/terraform-google-bigquery-loader-pubsub-ce/workflows/ci/badge.svg

[license]: https://docs.snowplow.io/limited-use-license-1.0/
[license-image]: https://img.shields.io/badge/license-Snowplow--Limited--Use-blue.svg?style=flat
[license-faq]: https://docs.snowplow.io/docs/contributing/limited-use-license-faq/

[registry]: https://registry.terraform.io/modules/snowplow-devops/bigquery-loader-pubsub-ce/google/latest
[registry-image]: https://img.shields.io/static/v1?label=Terraform&message=Registry&color=7B42BC&logo=terraform

[source]: https://github.com/snowplow-incubator/snowplow-bigquery-loader
[source-image]: https://img.shields.io/static/v1?label=Snowplow&message=BigQuery%20Loader&color=0E9BA4&logo=GitHub
