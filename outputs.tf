output "manager_id" {
  value = {
    for k, v in module.service : k => v.manager_id
  }
  description = "Identifier for the instance group manager"
}

output "manager_self_link" {
  value = {
    for k, v in module.service : k => v.manager_self_link
  }
  description = "The URL for the instance group manager"
}

output "instance_group_url" {
  value = {
    for k, v in module.service : k => v.instance_group_url
  }
  description = "The full URL of the instance group created by the manager"
}
