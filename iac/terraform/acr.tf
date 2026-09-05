resource "azurerm_container_registry" "main" {
  name                = replace("${var.prefix}acr", "-", "")
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# XID y XDB pull desde ACR con su Managed Identity
resource "azurerm_role_assignment" "xid_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.xid.principal_id
}

resource "azurerm_role_assignment" "xdb_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.xdb.principal_id
}
