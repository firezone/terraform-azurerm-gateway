variable "resource_group_location" {
  description = "The location for the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "source_image_reference" {
  description = "The source image reference for the instances"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })

  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

variable "instance_type" {
  description = "The instance type"
  type        = string
  default     = "Standard_B1ls"
}

variable "desired_capacity" {
  description = "The number of Gateway instances to deploy when using firezone_token (legacy). Defaults to 3. Must not be set when using firezone_tokens, where the number of instances is the length of the token list."
  type        = number
  default     = null
}

variable "admin_username" {
  description = "The admin username"
  type        = string
  default     = "firezone"
}

variable "admin_ssh_key" {
  description = "The admin SSH public key"
  type        = string
}

variable "firezone_token" {
  description = "A multi-owner Firezone token shared by all Gateway instances (legacy). New deployments should use firezone_tokens instead. Mutually exclusive with firezone_tokens."
  type        = string
  default     = null
  sensitive   = true
}

variable "firezone_tokens" {
  description = "A list of single-owner Firezone tokens, one per Gateway instance. Each token can only be used by one connected Gateway at a time. The number of Gateway instances deployed is the length of this list. Mutually exclusive with firezone_token."
  type        = list(string)
  default     = null
  sensitive   = true
}

variable "firezone_version" {
  description = "The Gateway version to deploy"
  type        = string
  default     = "latest"
}

variable "firezone_name" {
  description = "Name for the Gateways used in the admin portal"
  type        = string
  default     = "$(hostname)"
}

variable "firezone_api_url" {
  description = "The Firezone API URL"
  type        = string
  default     = "wss://api.firezone.dev"
}

variable "private_subnet" {
  description = "The private subnet ID"
  type        = string
}

variable "public_ipv6_prefix" {
  description = "The public IPv6 prefix to use"
  type        = string
  default     = null
}

variable "network_security_group_id" {
  description = "The network security group id to attach to the instances"
  type        = string
}

variable "extra_tags" {
  description = "Extra tags to attach to the instances"
  type        = map(string)
  default     = { "Name" = "firezone-gateway-instance" }
}

variable "platform_fault_domain_count" {
  description = "The number of fault domains"
  type        = number
  default     = 3
}

################################################################################
## Observability
################################################################################

variable "log_level" {
  description = "Sets RUST_LOG environment variable which applications should use to configure Rust Logger. Default: 'info'."
  nullable    = false
  type        = string
  default     = "info"
}

variable "log_format" {
  description = "Sets FIREZONE_LOG_FORMAT environment variable which applications should use to configure Rust Logger format. Default: 'human'."
  nullable    = false
  type        = string
  default     = "human"

  validation {
    condition     = contains(["human", "json"], var.log_format)
    error_message = "log_format must be either 'human' or 'json'."
  }
}

variable "observability_enable_flow_logs" {
  type     = bool
  nullable = false
  default  = false

  description = "Sets FIREZONE_FLOW_LOGS=true for the Gateway when enabled. Default: false."
}
