// Subscribe to region and create compartment steps are done manually
// all var. variables are from variables.tf file

// this variable is needed to delete DR setup
// runt this to delete
// terraform destroy -var "disassociate_trigger=1"
// and this to create
// // terraform destroy -var "disassociate_trigger=0"
variable "disassociate_trigger" { default = 0 }

locals {
  VCN01_cidr_block = "10.0.0.0/16"
  PUB-subnet       = "10.0.0.0/24"
}

module "sanjose" {
  source                      = "./../CH3FSDRSecondRegion"
  instance_id                 = oci_core_instance.web_server.id
  ashburn_protection_group_id = oci_disaster_recovery_dr_protection_group.fsdr_protection_group.id
}


data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}
// correct way to get namespace value for bucket
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

data "oci_core_vnic_attachments" "server_vnic_attachments" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.web_server.id
}

data "oci_core_images" "ubuntu_image" {
  compartment_id           = var.compartment_id
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
}

resource "oci_objectstorage_bucket" "mushop_bucket" {
  compartment_id = var.compartment_id
  name           = "mushop-45734"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

resource "oci_disaster_recovery_dr_protection_group" "fsdr_protection_group" {
  compartment_id = var.compartment_id
  display_name   = "mushop-ashburn"
  log_location {
    bucket    = oci_objectstorage_bucket.mushop_bucket.name
    namespace = data.oci_objectstorage_namespace.ns.namespace
  }
  // Seems that we have issue here
  // provider documentation here https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/disaster_recovery_dr_protection_group
  // says that
  /*
  association {
          #Required
          role = var.dr_protection_group_association_role

          #Optional
          peer_id = var.dr_protection_group_association_peer_id
          peer_region = var.dr_protection_group_association_peer_region
      }
  */
  // however if I'm setting up role = "VALUE" it gives me an error
  // │ Error: 400-InvalidParameter, Invalid peerRegion
  // and │ Error: 400-InvalidParameter, Invalid peerId
  // so those are not optional. It creates circular dependency as both DR protection groups must have
  // peerId of each other or second region gives and error
  // Error: 400-InvalidParameter, The DR Protection Group [mushop-sanjose] does not have a [Standby] role. A DR Plan cannot be created or updated when the DR Protection group has a [Unconfigured] role. Create a DR Plan on its peer instead.
  // which forces me to add "association" block to the second region as well
  // which leads to circular dependency as sanjose is created first and start to add plan and plan execution while Ashburn may not be created yet
  association {
    role        = "PRIMARY"
    peer_id     = module.sanjose.dr_protection_group_id
    peer_region = "us-sanjose-1"
  }
  members {
    member_id              = oci_core_instance.web_server.id
    is_movable             = true
    is_retain_fault_domain = false
    is_start_stop_enabled  = true
    // possible values
    //  [AUTONOMOUS_DATABASE COMPUTE_INSTANCE COMPUTE_INSTANCE_MOVABLE COMPUTE_INSTANCE_NON_MOVABLE DATABASE FILE_SYSTEM LOAD_BALANCER NETWORK_LOAD_BALANCER VOLUME_GROUP]
    member_type = "COMPUTE_INSTANCE"
    vnic_mapping {
      destination_subnet_id = module.sanjose.subnet_id
      source_vnic_id        = data.oci_core_vnic_attachments.server_vnic_attachments.vnic_attachments[0].vnic_id
    }
  }
  members {
    member_id   = oci_core_volume_group.web_server_volume_group.id
    member_type = "VOLUME_GROUP"
    block_volume_operations {
      attachment_details {
        volume_attachment_reference_instance_id = oci_core_instance.web_server.id
      }
      block_volume_id = oci_core_instance.web_server.boot_volume_id
    }
  }
}

// I will use only one instance here instead rather complicated setup
// with Autonomous database (which is kind of expensive and takes a long time to deploy)
// As all steps are similar for different types of resources,
// one instance is fine for educational purposes.
// My main goal is to show how to create a DR setup between two regions
// using terraform.

resource "oci_core_vcn" "VCN01" {
  cidr_block     = local.VCN01_cidr_block
  display_name   = "VCN01"
  dns_label      = "VCN01"
  compartment_id = var.compartment_id
}

resource "oci_core_subnet" "PUBsubnet" {
  cidr_block                 = local.PUB-subnet
  display_name               = "PUB-subnet"
  dns_label                  = "PUBsub"
  vcn_id                     = oci_core_vcn.VCN01.id
  compartment_id             = var.compartment_id
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_instance" "web_server" {
  compartment_id = var.compartment_id
  display_name   = "fsdr-demo-instance"
  //same AD as for private subnet
  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[0], "name")
  shape               = "VM.Standard.E5.Flex"
  source_details {
    source_id   = data.oci_core_images.ubuntu_image.images[0].id
    source_type = "image"
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.PUBsubnet.id
    assign_public_ip = true
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
}

resource "oci_core_volume_group" "web_server_volume_group" {
  compartment_id      = var.compartment_id
  display_name        = "web-server-volume-group"
  availability_domain = oci_core_instance.web_server.availability_domain
  source_details {
    type       = "volumeIds"
    volume_ids = [oci_core_instance.web_server.boot_volume_id]
  }
  volume_group_replicas {
    availability_domain = lookup(module.sanjose.sjc_ads[0], "name")
    display_name        = "web_server_volume_group_replica"
  }
}

// there is an issue with circular dependency
// full description is inside main.tf file of the module
module "sjc_dr_plan" {
  source                  = "./../CH3FSDRSecondRegion/FSDRPlan"
  sjc_protection_group_id = module.sanjose.dr_protection_group_id
  ashburn_fsdr            = oci_disaster_recovery_dr_protection_group.fsdr_protection_group
}