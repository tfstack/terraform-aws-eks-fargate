resource "helm_release" "this" {
  for_each = {
    for chart in var.helm_charts :
    chart.name => chart
    if chart.enabled != false
  }

  name             = each.value.name
  namespace        = each.value.namespace
  repository       = each.value.repository
  chart            = each.value.chart
  version          = try(each.value.chart_version, null)
  create_namespace = try(each.value.create_namespace, true)
  values           = try(each.value.values_files, [])

  dynamic "set" {
    for_each = try(each.value.set_values, [])
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  dynamic "set_sensitive" {
    for_each = try(each.value.set_sensitive_values, [])
    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
    }
  }
}
