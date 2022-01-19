terraform {
  required_providers {
    metal = {
      source = "equinix/metal"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
  }
  required_version = ">= 0.14"
}
