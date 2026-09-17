# Static Web Apps opcional para la WebApp dummy (desactivable con enable_swa=false).
# OJO: SWA Free no existe en eastus (sí en eastus2); lleva su propia variable.
resource "azurerm_static_web_app" "webapp" {
  count               = var.enable_swa ? 1 : 0
  name                = "${var.prefix}-webapp"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.swa_location
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = var.tags
}
