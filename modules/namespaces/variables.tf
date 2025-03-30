#########################################
# Toggle-Based Namespaces
#########################################

variable "enable_cloudwatch" {
  description = "Toggle for amazon-cloudwatch namespace"
  type        = bool
  default     = false
}

variable "enable_observability" {
  description = "Toggle for observability namespace"
  type        = bool
  default     = false
}

#########################################
# User-Defined Namespaces
#########################################

variable "namespaces" {
  description = "User-defined list of namespaces"
  type = list(object({
    name        = string
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
  }))
  default = null
}
