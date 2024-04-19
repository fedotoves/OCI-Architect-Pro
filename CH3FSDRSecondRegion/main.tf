// Subscribe to region and create compartment steps are done manually
// all var. variables are from variables.tf file
// As I don't need to create too many resources here, everything is in one file


// this is to get instance id from first region
variable "instance_id" {}
variable "ashburn_protection_group_id" {}
locals {
  VCN01_cidr_block = "10.0.0.0/16"
  PUB-subnet       = "10.0.0.0/24"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "mushop_bucket" {
  compartment_id = var.compartment_id
  name           = "mushop-45734"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

resource "oci_disaster_recovery_dr_protection_group" "sj_fsdr_protection_group" {
  compartment_id = var.compartment_id
  display_name   = "mushop-sanjose"
  log_location {
    bucket    = oci_objectstorage_bucket.mushop_bucket.name
    namespace = data.oci_objectstorage_namespace.ns.namespace
  }
}

// For disaster recovery plan and execution:
// seems that there is no terraform resource for custom steps
// in dr plan execution, so it should be done manually as showed in video
// the same is true for sequence of steps

resource "oci_core_vcn" "VCN01SJ" {
  cidr_block     = local.VCN01_cidr_block
  display_name   = "VCN01"
  dns_label      = "VCN01"
  compartment_id = var.compartment_id
}

resource "oci_core_subnet" "PUBsubnetSJ" {
  cidr_block                 = local.PUB-subnet
  display_name               = "PUB-subnet-SJ"
  dns_label                  = "PsubSJ"
  vcn_id                     = oci_core_vcn.VCN01SJ.id
  compartment_id             = var.compartment_id
  prohibit_public_ip_on_vnic = false
}

output "dr_protection_group_id" {
  value = oci_disaster_recovery_dr_protection_group.sj_fsdr_protection_group.id
}

output "vcn_id" {
  value = oci_core_vcn.VCN01SJ.id
}

output "subnet_id" {
  value = oci_core_subnet.PUBsubnetSJ.id
}

output "sjc_ads" {
  value = data.oci_identity_availability_domains.ads.availability_domains
}