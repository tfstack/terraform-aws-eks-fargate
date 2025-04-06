output "helm_release_names" {
  description = "Names of all enabled Helm releases"
  value       = [for r in helm_release.this : r.name]
}

output "helm_release_namespaces" {
  description = "Namespaces of all enabled Helm releases"
  value       = [for r in helm_release.this : r.namespace]
}

output "helm_release_statuses" {
  description = "Deployment statuses of all enabled Helm releases"
  value       = { for k, r in helm_release.this : k => r.status }
}
