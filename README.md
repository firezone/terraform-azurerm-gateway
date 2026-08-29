# Firezone Gateway module for Azure

Deploys one or more [Firezone](https://www.firezone.dev) Gateways as
orchestrated virtual machine scale sets in an existing VNet. Each instance
installs the Gateway on first boot using the official
[systemd install script](https://github.com/firezone/firezone/blob/main/scripts/gateway-systemd-install.sh)
and registers itself with your Firezone account.

## Prerequisites

- A Firezone account with a Site to deploy Gateways into. Generate deploy
  tokens from the admin portal under **Sites → \<site\> → Deploy Gateway**.
- An existing resource group and VNet with a subnet for the instances and
  egress to the internet (NAT Gateway or public IPs) so the Gateways can reach
  the Firezone API.
- A Debian-based image (Ubuntu LTS recommended, the default) — the install
  step uses `apt-get`.

## Usage

```hcl
module "gateway" {
  source = "firezone/gateway/azurerm"

  # One single-owner token per Gateway instance; one instance is deployed
  # per token.
  firezone_tokens = var.firezone_tokens

  resource_group_location = azurerm_resource_group.firezone.location
  resource_group_name     = azurerm_resource_group.firezone.name

  private_subnet            = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.firezone.id
  admin_ssh_key             = file("./id_rsa.pub")
}
```

See [examples/nat-gateway](./examples/nat-gateway) for a complete working
example including the VNet, subnets, NAT Gateway, and network security group.

### Legacy: multi-owner token

Multi-owner tokens are considered legacy and should only be used for existing
deployments. A single token is shared by every Gateway instance, and the
instance count is set with `desired_capacity`:

```hcl
module "gateway" {
  source = "firezone/gateway/azurerm"

  # A single multi-owner token shared by all Gateway instances (legacy).
  firezone_token   = var.firezone_token
  desired_capacity = 3

  resource_group_location = azurerm_resource_group.firezone.location
  resource_group_name     = azurerm_resource_group.firezone.name

  private_subnet            = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.firezone.id
  admin_ssh_key             = file("./id_rsa.pub")
}
```

## Token modes

The module supports both Firezone token types. Set exactly one of the two
variables:

| Mode | Variable | Behavior |
|------|----------|----------|
| Single-owner (default) | `firezone_tokens` | One token per instance; one single-instance scale set is deployed per token in the list. Each token can only be used by one connected Gateway at a time. |
| Multi-owner (legacy) | `firezone_token` | A single token shared by every Gateway instance in one scale set; the instance count is set with `desired_capacity`. |

Single-owner tokens are the default way to deploy Gateways. Multi-owner tokens
are considered legacy and are supported for existing deployments only; new
deployments should use single-owner tokens.

With single-owner tokens, the number of Gateway instances is determined by the
length of the token list — to scale up, append tokens; to scale down, remove
tokens from the end. Do not set `desired_capacity` in this mode. Tokens are
assigned to scale sets by list position: `firezone_tokens[0]` goes to scale
set `0`, and so on. A single-owner token can be reused by a replacement
instance once the previous Gateway using it has disconnected from the portal.
When changing the list, replace tokens in place rather than removing entries
from the middle — removing a middle entry shifts every token after it to a
different scale set and forces those instances to be replaced.

## High availability

Deploy at least 3 replicas for high availability. Gateways in the same Site
automatically load-balance and fail over. See the
[Gateway deployment docs](https://www.firezone.dev/kb/deploy/gateways) for
sizing and architecture recommendations.

## Upgrading and instance replacement

The Firezone token and other settings are passed via the custom script
extension, so changing `firezone_version`, tokens, or logging settings
**replaces the instances**. This is safe for connectivity as long as other
Gateways in the Site remain online, but plan for it in production: Terraform
may replace all instances in parallel. Pinning `firezone_version` (rather than
`latest`) keeps replacements reproducible.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `resource_group_location` | The location for the resource group. | `string` | n/a | yes |
| `resource_group_name` | The name of the resource group. | `string` | n/a | yes |
| `private_subnet` | The private subnet id. | `string` | n/a | yes |
| `network_security_group_id` | The network security group id to attach to the instances. | `string` | n/a | yes |
| `admin_ssh_key` | The admin SSH public key. | `string` | n/a | yes |
| `firezone_tokens` | A list of single-owner Firezone tokens, one per Gateway instance. One instance is deployed per token. Mutually exclusive with `firezone_token`. | `list(string)` | `null` | one of |
| `firezone_token` | A multi-owner Firezone token shared by all Gateway instances (legacy). Mutually exclusive with `firezone_tokens`. | `string` | `null` | one of |
| `desired_capacity` | The number of Gateway instances to deploy when using `firezone_token` (legacy). Must not be set with `firezone_tokens`. | `number` | `3` | no |
| `admin_username` | The admin username. | `string` | `"firezone"` | no |
| `source_image_reference` | The source image reference for the instances. This module assumes a Debian-based image. | `object` | Ubuntu 22.04 LTS | no |
| `instance_type` | The instance type. Gateways are lightweight; see [sizing recommendations](https://www.firezone.dev/kb/deploy/gateways#sizing-recommendations). | `string` | `"Standard_B1ls"` | no |
| `firezone_version` | The Gateway version to deploy. | `string` | `"latest"` | no |
| `firezone_api_url` | The Firezone API URL. | `string` | `"wss://api.firezone.dev"` | no |
| `public_ipv6_prefix` | The public IPv6 prefix to use. | `string` | `null` | no |
| `platform_fault_domain_count` | The number of fault domains. | `number` | `3` | no |
| `log_level` | Sets `RUST_LOG` for the Gateway process. | `string` | `"info"` | no |
| `log_format` | Sets `FIREZONE_LOG_FORMAT`. Either `human` or `json`. | `string` | `"human"` | no |
| `observability_enable_flow_logs` | Sets `FIREZONE_FLOW_LOGS=true` for the Gateway when enabled. | `bool` | `false` | no |
| `extra_tags` | Extra tags for the instances. | `map(string)` | `{ "Name" = "firezone-gateway-instance" }` | no |

## Outputs

This module currently exposes no outputs.

## Examples

- [NAT Gateway](./examples/nat-gateway): Deploy one or more Firezone Gateways
  in a single Azure VNet configured with a NAT Gateway for egress. Read this
  if you're looking to deploy Firezone Gateways behind a single, shared static
  IP address on Azure.

## License

See [LICENSE](./LICENSE).
