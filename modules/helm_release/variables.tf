variable "helm_charts" {
  description = "List of Helm releases to deploy"
  type = list(object({
    name                 = string
    namespace            = string
    repository           = string
    chart                = string
    chart_version        = optional(string)
    values_files         = optional(list(string), [])
    set_values           = optional(list(object({ name = string, value = string })), [])
    set_sensitive_values = optional(list(object({ name = string, value = string })), [])
    create_namespace     = optional(bool, true)
    enabled              = optional(bool, true)
    depends_on           = optional(list(any), [])
  }))

  validation {
    condition     = length(var.helm_charts) == 0 || alltrue([for c in var.helm_charts : can(c.name) && can(c.namespace) && can(c.chart) && can(c.repository)])
    error_message = "Each helm chart must include name, namespace, chart, and repository."
  }
}
