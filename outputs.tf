output "named_port_http" {
  value       = module.service.named_port_http
  description = "The name of the port exposed by the instance group"
}

output "named_port_value" {
  value       = module.service.named_port_value
  description = "The named port value (e.g. 8080)"
}

output "manager_id" {
  value       = module.service.manager_id
  description = "Identifier for the instance group manager"
}

output "manager_self_link" {
  value       = module.service.manager_self_link
  description = "The URL for the instance group manager"
}

output "instance_group_url" {
  value       = module.service.instance_group_url
  description = "The full URL of the instance group created by the manager"
}

output "health_check_id" {
  value       = module.service.health_check_id
  description = "Identifier for the health check on the instance group"
}

output "health_check_self_link" {
  value       = module.service.health_check_self_link
  description = "The URL for the health check on the instance group"
}
