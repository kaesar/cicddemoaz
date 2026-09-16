resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.prefix}-cosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  # Free tier (1000 RU/s + 25 GB de por vida, incompatible con serverless; uno por subscription y solo al crear).
  free_tier_enabled = var.cosmos_free_tier

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_db_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "kv" {
  name                  = var.cosmos_container_name
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths   = ["/id"]
  partition_key_version = 1
  throughput            = var.cosmos_throughput
}

# XDB lee Cosmos vía Key Vault (endpoint+key como secrets); rol opcional si se usa RBAC nativo.
resource "azurerm_role_assignment" "xdb_cosmos_reader" {
  scope                = azurerm_cosmosdb_account.main.id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = azurerm_user_assigned_identity.xdb.principal_id
}
