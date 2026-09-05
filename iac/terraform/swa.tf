# Static Web Apps opcional para la WebApp dummy (desactivable con enable_swa=false)
resource "azurerm_static_web_app" "webapp" {
  count               = var.enable_swa ? 1 : 0
  name                = "${var.prefix}-webapp"
  resource_group_name = azurerm_resource_group.main.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = var.tags
}
