output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "storage_account" {
  value = azurerm_storage_account.images.name
}

output "function_app_url" {
  value = "https://${azurerm_linux_function_app.app.default_hostname}"
}

output "vision_endpoint" {
  value = azurerm_cognitive_account.vision.endpoint
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "static_web_app_url" {
  value       = var.enable_static_web_app && length(azurerm_static_site.swa) > 0 ? azurerm_static_site.swa[0].default_host_name : "(not created)"
  description = "URL for the Static Web App, if created."
}

output "key_vault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "Key Vault URI that stores secrets for the Function App."
}

output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "Virtual network used for function integration and private endpoints."
}

output "function_subnet_id" {
  value       = azurerm_subnet.function_integration.id
  description = "Subnet delegated to the Function App for VNet integration."
}
