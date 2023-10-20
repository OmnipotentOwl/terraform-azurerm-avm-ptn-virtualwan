resource "azurerm_firewall" "fw" {
  for_each = var.firewalls

  name                = each.value.name
  location            = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_name].location
  resource_group_name = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_name].resource_group_name
  sku_name            = each.value.sku_name
  sku_tier            = each.value.sku_tier
  firewall_policy_id  = each.value.firewall_policy_id
  threat_intel_mode   = each.value.threat_intel_mode
  zones               = each.value.zones
  tags                = try(each.value.tags, {})

  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_name].id
    public_ip_count = each.value.vhub_public_ip_count
  }
}