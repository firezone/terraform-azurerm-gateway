resource "azurerm_orchestrated_virtual_machine_scale_set" "firezone" {
  name                        = "firezone-gateway-vmss-${replace(var.resource_group_location, " ", "")}"
  location                    = var.resource_group_location
  resource_group_name         = var.resource_group_name
  sku_name                    = var.instance_type
  instances                   = var.desired_capacity
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
    enable_ip_forwarding = true

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
      export FIREZONE_TOKEN="${var.firezone_token}"
      export FIREZONE_VERSION="${var.firezone_version}"
      export FIREZONE_NAME="${var.firezone_name}"
      export FIREZONE_ID="$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)"
      export FIREZONE_API_URL="${var.firezone_api_url}"

      # Download and execute the Firezone installation script
      # The extension handler will retry this automatically if it fails
      curl -fsSL https://raw.githubusercontent.com/firezone/firezone/main/scripts/gateway-systemd-install.sh | bash

      echo "Firezone Gateway installation completed successfully"
      SCRIPT
      )
    })
  }

  tags = var.extra_tags
}
