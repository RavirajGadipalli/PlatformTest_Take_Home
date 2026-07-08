terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Production state should live in remote backend (Azure Storage + state locking).
  # Left local here so the take-home can run without extra Azure resources.
  # backend "azurerm" { ... }
}

provider "azurerm" {
  features {}
}

locals {
  # Prefix every resource with app + environment so nonprod and prod don't collide.
  name_prefix = "${var.app_name}-${var.environment}"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location

  tags = {
    environment = var.environment
    application = var.app_name
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  # Shorter retention in nonprod saves cost; prod keeps logs longer for incident review.
  retention_in_days = var.log_retention_days
}

resource "azurerm_container_registry" "main" {
  # ACR names must be alphanumeric and globally unique.
  name                = "acr${replace(local.name_prefix, "-", "")}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"

  # Admin account exposes long-lived credentials; use managed identity for image pull instead.
  admin_enabled = false
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_prefix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# User-assigned identity is created before the app so AcrPull can be granted without a chicken-and-egg pull failure.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${local.name_prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  template {
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/myapp-api:${var.image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.environment == "prod" ? "Production" : "Development"
      }

      # Reference secrets by name — never put credentials directly in env { value = ... }.
      env {
        name        = "ConnectionStrings__Database"
        secret_name = "database-connection-string"
      }

      env {
        name        = "API_KEY"
        secret_name = "api-key"
      }

      env {
        name        = "DATADOG_API_KEY"
        secret_name = "datadog-api-key"
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    target_port      = 8080
    transport        = "http"
    external_enabled = true

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Pull from ACR using the user-assigned managed identity (no username/password).
  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  secret {
    name  = "database-connection-string"
    value = var.database_connection_string
  }

  secret {
    name  = "api-key"
    value = var.api_key
  }

  secret {
    name  = "datadog-api-key"
    value = var.datadog_api_key
  }

  # In production, source these secret values from Azure Key Vault secret references
  # instead of Terraform variables so they never appear in state or pipeline logs.
}

# Grant the identity permission to pull images from ACR.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
