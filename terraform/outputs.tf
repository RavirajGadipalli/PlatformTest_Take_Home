output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.main.name
}

output "container_app_url" {
  description = "Public HTTPS URL for the Container App."
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "acr_login_server" {
  description = "ACR login server for docker push/pull in CI."
  value       = azurerm_container_registry.main.login_server
}

# Intentionally omit ACR admin credentials — admin account is disabled.
# CI should authenticate with az acr login and a service principal or managed identity.
