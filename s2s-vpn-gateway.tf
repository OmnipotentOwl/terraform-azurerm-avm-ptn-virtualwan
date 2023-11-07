resource "azurerm_vpn_gateway" "vpn_gateway" {
  for_each = local.vpn_gateways != null && length(local.vpn_gateways) > 0 ? local.vpn_gateways : {}

  name                = each.value.name
  location            = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub].location
  resource_group_name = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub].resource_group_name
  virtual_hub_id      = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub].id

  bgp_route_translation_for_nat_enabled = each.value.bgp_route_translation_for_nat_enabled
  routing_preference                    = each.value.routing_preference
  scale_unit                            = each.value.scale_unit
  tags                                  = try(each.value.tags, {})

  dynamic "bgp_settings" {
    for_each = each.value.bgp_settings != null ? [each.value.bgp_settings] : []
    content {
      asn         = bgp_settings.value.asn
      peer_weight = bgp_settings.value.peer_weight
      dynamic "instance_0_bgp_peering_address" {
        for_each = bgp_settings.value.instance_0_bgp_peering_address != null ? [bgp_settings.value.instance_0_bgp_peering_address] : []
        content {
          custom_ips = instance_0_bgp_peering_address.value
        }
      }
      dynamic "instance_1_bgp_peering_address" {
        for_each = bgp_settings.value.instance_1_bgp_peering_address != null ? [bgp_settings.value.instance_1_bgp_peering_address] : []
        content {
          custom_ips = instance_1_bgp_peering_address.value
        }
      }
    }
  }
}

# Create a vpn site. Sites represent the Physical locations (On-Premises) you wish to connect.
resource "azurerm_vpn_site" "vpn_site" {
  for_each = local.vpn_sites != null ? local.vpn_sites : {}

  name                = each.value.name
  location            = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_name].location
  resource_group_name = azurerm_virtual_hub.virtual_hub[each.value.virtual_hub_name].resource_group_name
  virtual_wan_id      = azurerm_virtual_wan.virtual_wan.id
  address_cidrs       = each.value.address_cidrs
  dynamic "link" {
    for_each = each.value.links != null ? each.value.links : []

    content {
      name          = link.value.name
      ip_address    = try(link.value.ip_address, null)
      fqdn          = try(link.value.fqdn, null)
      speed_in_mbps = link.value.speed_in_mbps

      dynamic "bgp" {
        for_each = link.value.bgp != null ? [link.value.bgp] : []

        content {
          asn             = bgp.value.asn
          peering_address = bgp.value.peering_address
        }
      }
      provider_name = try(link.value.provider_name, null)
    }
  }
  device_model  = each.value.device_model
  device_vendor = each.value.device_vendor

  dynamic "o365_policy" {
    for_each = each.value.o365_policy != null ? [each.value.o365_policy] : []
    content {
      dynamic "traffic_category" {
        for_each = o365_policy.value.traffic_category != null ? [o365_policy.value.traffic_category] : []
        content {
          allow_endpoint_enabled    = traffic_category.value.allow_endpoint_enabled
          default_endpoint_enabled  = traffic_category.value.default_endpoint_enabled
          optimize_endpoint_enabled = traffic_category.value.optimize_endpoint_enabled
        }
      }
    }
  }
  tags = try(each.value.tags, {})
}

# Create a site to site vpn connection between a vpn gateway and a vpn site.
resource "azurerm_vpn_gateway_connection" "vpn_site_connection" {
  for_each = local.vpn_site_connections != null && length(local.vpn_site_connections) > 0 ? local.vpn_site_connections : {}

  name               = each.value.name
  vpn_gateway_id     = azurerm_vpn_gateway.vpn_gateway[each.value.vpn_gateway_name].id
  remote_vpn_site_id = azurerm_vpn_site.vpn_site[each.value.remote_vpn_site_name].id

  dynamic "vpn_link" {
    for_each = each.value.vpn_links != null ? each.value.vpn_links : {}

    content {
      name = vpn_link.value.name
      #Apply workaround for https://github.com/hashicorp/terraform-provider-azurerm/issues/18597
      vpn_site_link_id = "${azurerm_vpn_site.vpn_site[each.value.remote_vpn_site_name].id}/vpnSiteLinks/${azurerm_vpn_site.vpn_site[each.value.remote_vpn_site_name].link[vpn_link.value.vpn_site_link_number].name}"
      #azurerm_vpn_site.vpn_site[each.value.remote_vpn_site_name].link[vpn_link.value.vpn_site_link_number].id
      bandwidth_mbps       = try(vpn_link.value.bandwidth_mbps, null)
      bgp_enabled          = try(vpn_link.value.bgp_enabled, null)
      connection_mode      = try(vpn_link.value.connection_mode, null)
      egress_nat_rule_ids  = try(vpn_link.value.egress_nat_rule_ids, null)
      ingress_nat_rule_ids = try(vpn_link.value.ingress_nat_rule_ids, null)

      dynamic "ipsec_policy" {
        for_each = vpn_link.value.ipsec_policy != null ? [vpn_link.value.ipsec_policy] : []

        content {
          dh_group                 = ipsec_policy.value.dh_group
          ike_encryption_algorithm = ipsec_policy.value.ike_encryption_algorithm
          ike_integrity_algorithm  = ipsec_policy.value.ike_integrity_algorithm
          encryption_algorithm     = ipsec_policy.value.encryption_algorithm
          integrity_algorithm      = ipsec_policy.value.integrity_algorithm
          pfs_group                = ipsec_policy.value.pfs_group
          sa_data_size_kb          = ipsec_policy.value.sa_data_size_kb
          sa_lifetime_sec          = ipsec_policy.value.sa_lifetime_sec
        }
      }
      protocol                              = try(vpn_link.value.protocol, null)
      ratelimit_enabled                     = try(vpn_link.value.ratelimit_enabled, null)
      route_weight                          = try(vpn_link.value.route_weight, null)
      shared_key                            = try(vpn_link.value.shared_key, null)
      local_azure_ip_address_enabled        = try(vpn_link.value.local_azure_ip_address_enabled, null)
      policy_based_traffic_selector_enabled = try(vpn_link.value.policy_based_traffic_selector_enabled, null)

      dynamic "custom_bgp_address" {
        for_each = vpn_link.value.custom_bgp_address != null ? [vpn_link.value.custom_bgp_address] : []

        content {
          ip_address          = custom_bgp_address.value.ip_address
          ip_configuration_id = custom_bgp_address.value.ip_configuration_id
        }
      }
    }
  }
  internet_security_enabled = try(each.value.internet_security_enabled, null)
  dynamic "routing" {
    for_each = each.value.routing != null ? [each.value.routing] : []

    content {
      associated_route_table = routing.value.associated_route_table

      dynamic "propagated_route_table" {
        for_each = routing.value.propagated_route_table != null ? [routing.value.propagated_route_table] : []

        content {
          route_table_ids = propagated_route_table.value.route_table_ids
          labels          = propagated_route_table.value.labels
        }
      }
    }
  }
  dynamic "traffic_selector_policy" {
    for_each = each.value.traffic_selector_policy != null ? [each.value.traffic_selector_policy] : []

    content {
      local_address_ranges  = traffic_selector_policy.value.local_address_ranges
      remote_address_ranges = traffic_selector_policy.value.remote_address_ranges
    }
  }
}

