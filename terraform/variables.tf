variable "environment" {
  description = "Deployment environment (e.g. nonprod, prod). Drives resource naming and ASPNETCORE_ENVIRONMENT."
  type        = string

  validation {
    condition     = contains(["nonprod", "prod"], var.environment)
    error_message = "environment must be either nonprod or prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "West US"
}

variable "app_name" {
  description = "Short application name used in resource naming."
  type        = string
}

variable "image_tag" {
  description = "Container image tag to deploy. Avoid 'latest' in production — pin to a build ID or digest."
  type        = string
}

variable "database_connection_string" {
  description = "SQL connection string for the application. Supply via tfvars or CI secret variable — never commit real values."
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "External API key for the application."
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key for telemetry."
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "Log Analytics retention period in days."
  type        = number
  default     = 30
}

variable "min_replicas" {
  description = "Minimum container replicas. Use 0 in nonprod to save cost; use >= 1 in prod to avoid cold starts."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum container replicas for autoscaling."
  type        = number
  default     = 3
}
