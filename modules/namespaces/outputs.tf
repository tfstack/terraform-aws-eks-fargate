output "namespace_names" {
  description = "List of all created Kubernetes namespaces"
  value       = [for ns in kubernetes_namespace.this : ns.metadata[0].name]
}

output "namespace_labels" {
  description = "Map of namespace names to their labels"
  value = {
    for ns in kubernetes_namespace.this :
    ns.metadata[0].name => ns.metadata[0].labels
  }
}

output "namespace_annotations" {
  description = "Map of namespace names to their annotations"
  value = {
    for ns in kubernetes_namespace.this :
    ns.metadata[0].name => ns.metadata[0].annotations
  }
}
