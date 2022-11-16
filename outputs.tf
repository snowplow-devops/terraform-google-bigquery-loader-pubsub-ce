output "manager_id" {
  value = {
    for k, v in google_compute_region_instance_group_manager.grp : k => v.id
  }
  description = "Identifier for the instance group manager"
}

output "manager_self_link" {
  value = {
    for k, v in google_compute_region_instance_group_manager.grp : k => v.self_link
  }
  description = "The URL for the instance group manager"
}

output "instance_group_url" {
  value = {
    for k, v in google_compute_region_instance_group_manager.grp : k => v.instance_group
  }
  description = "The full URL of the instance group created by the manager"
}
