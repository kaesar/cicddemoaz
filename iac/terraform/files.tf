# Azure Files para los ficheros de xid (xusers.txt / xclients.txt).
# Reaprovecha la cuenta del tfstate: el share lo crea el pipeline
# (az storage share-rm) ANTES del apply; aquí solo se registra como
# Environment Storage para montarlo en /data de la app xid.
resource "azurerm_container_app_environment_storage" "xid_data" {
  name                         = "${var.prefix}-xid-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = var.files_storage_account_name
  share_name                   = var.files_share_name
  access_key                   = var.files_storage_account_key
  access_mode                  = "ReadWrite"
}
