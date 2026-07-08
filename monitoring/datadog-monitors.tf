terraform {
  required_version = ">= 1.3.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}

provider "datadog" {
  # Keys must come from environment variables or CI secrets — never hardcode in source control.
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = var.datadog_api_url
}

locals {
  monitor_tags = [
    "env:${var.environment}",
    "service:${var.service_name}",
    "managed-by:terraform",
  ]

  # Scope every query to this environment so nonprod noise doesn't page prod on-call.
  metric_filter = "container_app_name:${var.container_app_name},env:${var.environment}"
  trace_filter  = "service:${var.service_name},env:${var.environment}"
  log_filter    = "service:${var.service_name} status:error env:${var.environment}"
}

resource "datadog_monitor" "cpu_high" {
  name    = "[${var.environment}] ${var.app_name} — High CPU"
  type    = "metric alert"
  message = <<-EOT
    CPU usage is elevated on ${var.container_app_name}.
    Check recent deployments and autoscaling settings.
    ${var.oncall_notification}
  EOT

  # Use a 5-minute window — 1-minute CPU spikes cause alert fatigue.
  query = "avg(last_5m):avg:azure.containerapps.container.cpu.usage{${local.metric_filter}} > 80"

  monitor_thresholds {
    warning  = 70
    critical = 80
  }

  tags                  = local.monitor_tags
  require_full_window   = true
  include_tags          = true
  # Azure metrics can arrive late; delay evaluation to avoid false negatives.
  evaluation_delay      = 300
  notify_no_data        = false
  priority              = var.environment == "prod" ? 2 : 4
}

resource "datadog_monitor" "response_time" {
  name    = "[${var.environment}] ${var.app_name} — Slow HTTP Response"
  type    = "metric alert"
  message = <<-EOT
    P95 HTTP response time is above threshold for ${var.service_name}.
    Check downstream dependencies and recent deploys.
    ${var.oncall_notification}
  EOT

  # P95 is more representative of user experience than a plain average.
  query = "avg(last_5m):p95:trace.http.request.duration{${local.trace_filter}} > 1"

  monitor_thresholds {
    warning  = 0.5
    critical = 1
  }

  tags                = local.monitor_tags
  require_full_window = true
  include_tags        = true
  priority            = var.environment == "prod" ? 2 : 4
}

resource "datadog_monitor" "http_5xx_rate" {
  name    = "[${var.environment}] ${var.app_name} — Elevated HTTP 5xx Errors"
  type    = "metric alert"
  message = <<-EOT
    HTTP 5xx error rate is elevated for ${var.service_name}.
  EOT

  query = "sum(last_5m):sum:trace.http.request.errors{${local.trace_filter}}.as_count() > 10"

  monitor_thresholds {
    warning  = 5
    critical = 10
  }

  tags                = local.monitor_tags
  require_full_window = true
  include_tags        = true
  priority            = var.environment == "prod" ? 1 : 3
}

resource "datadog_monitor" "error_log" {
  name    = "[${var.environment}] ${var.app_name} — Error Log Volume"
  type    = "log alert"
  message = <<-EOT
    Error log volume is elevated for ${var.service_name} in ${var.environment}.
    ${var.oncall_notification}
  EOT

  # A single transient error should not page on-call — threshold a burst instead.
  # Scope to service + env and a dedicated index rather than logs("*").
  query = "logs(\"${local.log_filter}\").index(\"${var.log_index}\").rollup(\"count\").last(\"5m\") > 10"

  monitor_thresholds {
    warning  = 5
    critical = 10
  }

  tags     = local.monitor_tags
  priority = var.environment == "prod" ? 2 : 4
}

resource "datadog_monitor" "replica_count" {
  count = var.min_expected_replicas > 0 ? 1 : 0

  name    = "[${var.environment}] ${var.app_name} — No Running Replicas"
  type    = "metric alert"
  message = <<-EOT
    ${var.container_app_name} has fewer than ${var.min_expected_replicas} running replica(s).
    ${var.oncall_notification}
  EOT

  # Replaces the process.up service check — ACA exposes replica count via Azure metrics.
  query = "avg(last_5m):avg:azure.containerapps.management.replicas.count{${local.metric_filter}} < ${var.min_expected_replicas}"

  monitor_thresholds {
    critical = var.min_expected_replicas
  }

  tags              = local.monitor_tags
  notify_no_data    = true
  no_data_timeframe = 10
  include_tags      = true
  priority          = 1
}

resource "datadog_dashboard" "app_dashboard" {
  title       = "${var.app_name} — ${var.environment}"
  description = "Operational dashboard for ${var.service_name} in ${var.environment}"
  layout_type = "ordered"

  tags = local.monitor_tags

  widget {
    timeseries_definition {
      title = "CPU Usage"
      request {
        q            = "avg:azure.containerapps.container.cpu.usage{${local.metric_filter}}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Memory Usage"
      request {
        q            = "avg:azure.containerapps.container.memory.usage{${local.metric_filter}}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Request Rate"
      request {
        q            = "sum:trace.http.request.hits{${local.trace_filter}}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "HTTP 5xx Errors"
      request {
        q            = "sum:trace.http.request.errors{${local.trace_filter}}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Running Replicas"
      request {
        q            = "avg:azure.containerapps.management.replicas.count{${local.metric_filter}}"
        display_type = "line"
      }
    }
  }
}
