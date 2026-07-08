variable "environment" {
  description = "Deployment environment (nonprod or prod). Used in monitor names, queries, and tags."
  type        = string

  validation {
    condition     = contains(["nonprod", "prod"], var.environment)
    error_message = "environment must be either nonprod or prod."
  }
}

variable "app_name" {
  description = "Application name — must match Terraform app_name."
  type        = string
  default     = "myapp"
}

variable "service_name" {
  description = "APM service name used in trace metrics."
  type        = string
  default     = "myapp-api"
}

variable "container_app_name" {
  description = "Azure Container App resource name (e.g. ca-myapp-prod-api)."
  type        = string
}

variable "min_expected_replicas" {
  description = "Minimum healthy replica count. Set to 0 for nonprod (scale-to-zero), 1+ for prod."
  type        = number
  default     = 1
}

variable "datadog_api_key" {
  description = "Datadog API key. Supply via TF_VAR_datadog_api_key or a CI secret — never commit."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key for Terraform. Supply via TF_VAR_datadog_app_key or a CI secret."
  type        = string
  sensitive   = true
}

variable "datadog_api_url" {
  description = "Datadog API URL (https://api.datadoghq.com/ for US1, https://api.datadoghq.eu/ for EU)."
  type        = string
  default     = "https://api.datadoghq.com/"
}

variable "oncall_notification" {
  description = "Datadog notification handle (e.g. @pagerduty-myapp or @slack-platform-alerts)."
  type        = string
  default     = "@oncall-platform"
}

variable "log_index" {
  description = "Datadog log index to query. Avoid '*' in production — scope to a dedicated index."
  type        = string
  default     = "main"
}
