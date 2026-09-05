data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  # RBAC (recomendado) en lugar de access policies legacy
  enable_rbac_authorization = true
}

# Deployer (quien aplica terraform) administra secretos
resource "azurerm_role_assignment" "deployer_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# XID/XDB solo leen secretos
resource "azurerm_role_assignment" "xid_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.xid.principal_id
}

resource "azurerm_role_assignment" "xdb_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.xdb.principal_id
}

# Placeholders de secretos: rellenar vía pipeline (az keyvault secret set) o terraform.tfvars.
# Se declaran como recursos vacíos para fijar el nombre; el valor real lo pone el pipeline.
resource "azurerm_key_vault_secret" "xid_rsa_jwk" {
  name         = "xid-rsa-jwk"
  value        = "REPLACE-via-pipeline"
  key_vault_id = azurerm_key_vault.main.id
  lifecycle {
    ignore_changes = [value]
  }
  depends_on = [azurerm_role_assignment.deployer_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "xid_client_secret" {
  name         = "xid-client-secret"
  value        = "REPLACE-via-pipeline"
  key_vault_id = azurerm_key_vault.main.id
  lifecycle {
    ignore_changes = [value]
  }
  depends_on = [azurerm_role_assignment.deployer_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.main.primary_key
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmos-endpoint"
  value        = azurerm_cosmosdb_account.main.endpoint
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_kv_secrets_officer]
}
