terraform {
  required_version = ">= 0.15"
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">=5.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.1"
    }
  }
}