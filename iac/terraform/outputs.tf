output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "xid_url" {
  value = azurerm_container_app.xid.ingress[0].fqdn
}

output "xdb_url" {
  value = azurerm_container_app.xdb.ingress[0].fqdn
}

output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.main.endpoint
  description = "Endpoint Cosmos DB (la key vive en Key Vault)"
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "swa_hostname" {
  value = var.enable_swa ? azurerm_static_web_app.webapp[0].default_host_name : ""
}
