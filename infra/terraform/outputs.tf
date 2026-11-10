output "namespaces" {
  description = "Namespace for each environment (Ansible and Jenkins use these names)"
  value       = { for k, v in var.environments : k => v.namespace }
}
