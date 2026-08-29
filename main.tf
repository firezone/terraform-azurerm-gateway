locals {
  # In single-owner mode one scale set is deployed per token, each with a
  # single instance; in legacy multi-owner mode a single scale set runs
  # var.desired_capacity (default 3) instances sharing one token.
  tokens = var.firezone_tokens != null ? var.firezone_tokens : [var.firezone_token]
}

moved {
  from = azurerm_orchestrated_virtual_machine_scale_set.firezone
  to   = azurerm_orchestrated_virtual_machine_scale_set.firezone[0]
}

resource "azurerm_orchestrated_virtual_machine_scale_set" "firezone" {
  count = length(local.tokens)

  name = var.firezone_tokens != null ? (
    "firezone-gateway-vmss-${count.index}-${replace(var.resource_group_location, " ", "")}"
    ) : (
    "firezone-gateway-vmss-${replace(var.resource_group_location, " ", "")}"
  )
  location                    = var.resource_group_location
  resource_group_name         = var.resource_group_name
  sku_name                    = var.instance_type
  instances                   = var.firezone_tokens != null ? 1 : coalesce(var.desired_capacity, 3)
  platform_fault_domain_count = var.platform_fault_domain_count

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  network_interface {
    name    = "firezone-nic"
    primary = true

    # Required to egress traffic
    ip_forwarding_enabled = true

    network_security_group_id = var.network_security_group_id

    ip_configuration {
      name      = "internal-ipv4"
      primary   = true
      subnet_id = var.private_subnet
      version   = "IPv4"
    }

    dynamic "ip_configuration" {
      for_each = var.public_ipv6_prefix != null ? [1] : []
      content {
        name      = "internal-ipv6"
        primary   = false
        subnet_id = var.private_subnet
        version   = "IPv6"
        public_ip_address {
          name                = "public-ipv6"
          version             = "IPv6"
          public_ip_prefix_id = var.public_ipv6_prefix
          sku_name            = "Standard_Regional"
        }
      }
    }
  }

  os_profile {
    linux_configuration {
      admin_username = var.admin_username

      admin_ssh_key {
        username   = var.admin_username
        public_key = var.admin_ssh_key
      }
    }
  }

  os_disk {
    caching              = "None"
    storage_account_type = "Premium_LRS"
  }

  extension {
    name                 = "firezone-gateway-install"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.1"

    settings = jsonencode({
      script = base64encode(<<-SCRIPT
      #!/bin/bash
      set -euo pipefail

      # Export environment variables for the installation script
      export FIREZONE_TOKEN="${local.tokens[count.index]}"
      export FIREZONE_VERSION="${var.firezone_version}"
      export FIREZONE_NAME="${var.firezone_name}"
      export FIREZONE_ID="$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)"
      export FIREZONE_API_URL="${var.firezone_api_url}"
      export FIREZONE_LOG_FORMAT="${var.log_format}"
      %{if var.observability_enable_flow_logs}
      export FIREZONE_FLOW_LOGS="true"
      %{endif}
      export RUST_LOG="${var.log_level}"

      # Download and execute the Firezone installation script
      # The extension handler will retry this automatically if it fails
      curl -fsSL https://raw.githubusercontent.com/firezone/firezone/main/scripts/gateway-systemd-install.sh | bash

      echo "Firezone Gateway installation completed successfully"
      SCRIPT
      )
    })
  }

  tags = var.extra_tags

  lifecycle {
    precondition {
      condition     = (var.firezone_token != null) != (var.firezone_tokens != null)
      error_message = "Exactly one of firezone_token (multi-owner, legacy) or firezone_tokens (single-owner, one per instance) must be set."
    }

    precondition {
      condition     = var.firezone_tokens == null || var.desired_capacity == null
      error_message = "desired_capacity cannot be set when firezone_tokens is used; the number of instances is determined by the length of the token list."
    }
  }
}
