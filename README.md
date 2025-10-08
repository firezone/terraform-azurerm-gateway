# Firezone Terraform modules and examples

This repo contains Terraform modules to use for Firezone deployments on
Microsoft Azure.

## Examples

- [NAT Gateway](./examples/nat-gateway): This example shows how to deploy
  one or more Firezone Gateways in a single Azure VNet that is configured with a
  NAT Gateway for egress. Read this if you're looking to deploy Firezone
  Gateways behind a single, shared static IP address on AWS.
