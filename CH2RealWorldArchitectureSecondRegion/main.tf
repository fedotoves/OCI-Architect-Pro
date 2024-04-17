// Subscribe to region and create compartment steps are done manually
// all var. variables are from variables.tf file
// As I don't need to create too many resources here, everything is in one file

variable "peering_connection_to_frankfurt_id" {
}
variable "CorporateVCN_cidr_block" {
}
variable "CorporateVCN_public_subnet_cidr_block" {
}
variable "CorporateVCN_private_subnet_cidr_block" {
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "ImageBucketFRA" {
  compartment_id = var.compartment_id
  name           = "ImageBucketFRA"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

resource "oci_core_vcn" "CorporateVCN" {
  cidr_block     = var.CorporateVCN_cidr_block
  display_name   = "CorporateVCN"
  dns_label      = "CorporateVCN"
  compartment_id = var.compartment_id
}

# public subnet for CorporateVCN
resource "oci_core_subnet" "CorporateVCNPubSub" {
  availability_domain        = lookup(data.oci_identity_availability_domains.ads.availability_domains[0], "name")
  cidr_block                 = var.CorporateVCN_public_subnet_cidr_block
  display_name               = "CorpVCNPubSub"
  dns_label                  = "CorpVCNPubSub"
  vcn_id                     = oci_core_vcn.CorporateVCN.id
  route_table_id             = oci_core_vcn.CorporateVCN.default_route_table_id
  compartment_id             = var.compartment_id
  prohibit_public_ip_on_vnic = false
}

# private subnet for CorporateVCN
resource "oci_core_subnet" "CorporateVCNPrivateSub" {
  availability_domain        = lookup(data.oci_identity_availability_domains.ads.availability_domains[0], "name")
  cidr_block                 = var.CorporateVCN_private_subnet_cidr_block
  display_name               = "CorpVCNPrSub"
  dns_label                  = "CorpVCNPrSub"
  vcn_id                     = oci_core_vcn.CorporateVCN.id
  prohibit_public_ip_on_vnic = true
  compartment_id             = var.compartment_id
}

// Frankfurt is my second region
resource "oci_core_drg" "FrankfurtDRG" {
  compartment_id = var.compartment_id
  display_name   = "FrankfurtDRG"
}

resource "oci_core_drg_attachment" "FrankfurtDRG_attachment" {
  drg_id = oci_core_drg.FrankfurtDRG.id
  network_details {
    id   = oci_core_vcn.CorporateVCN.id
    type = "VCN"
  }
}

resource "oci_core_remote_peering_connection" "peering_connection_to_ashburn" {
  compartment_id = var.compartment_id
  drg_id         = oci_core_drg.FrankfurtDRG.id
  display_name   = "2Ashburn"
  // when you assign values to those two variables, real connection is established
  peer_id          = var.peering_connection_to_frankfurt_id
  peer_region_name = "us-ashburn-1"
}

// creating separate route table instead of adding rule to existing one
// querying for route table and modifying rules can be time consuming
resource "oci_core_route_table" "DRGFraPeeringRouteTable" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.CorporateVCN.id
  display_name   = "DRG Fra Peering Route Table"
  route_rules {
    // you can query for this value, but it is time consuming, so far leaving it hardcoded
    destination       = "172.16.1.0/24"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.FrankfurtDRG.id
  }
}

// need for fastconnect
// you need to request / check if cross_connect service limit allows
// creation of cross_connect. I had to request one
resource "oci_core_cross_connect" "to_on_prem_cross_connect" {
  compartment_id        = var.compartment_id
  location_name         = "Equinix FR5"
  port_speed_shape_name = "10 Gbps"
  // important. Used to move to "ACTIVE" state
  is_active = true
}

// Fast Connect is created using virtual circuit resource in terraform
// takes about 3 min
resource "oci_core_virtual_circuit" "to_on_prem" {
  compartment_id       = var.compartment_id
  type                 = "PRIVATE"
  bandwidth_shape_name = "10 Gbps"
  // took those values from video, in real project you need to get them - don't know how for now
  // but worth researching it
  cross_connect_mappings {
    customer_bgp_peering_ip                 = "10.0.0.22/30"
    customer_bgp_peering_ipv6               = "2001:db8:0:cc00::1/126"
    oracle_bgp_peering_ip                   = "10.0.0.21/30"
    oracle_bgp_peering_ipv6                 = "2001:db8:0:cc00::2/126"
    vlan                                    = 200
    cross_connect_or_cross_connect_group_id = oci_core_cross_connect.to_on_prem_cross_connect.id
  }

  customer_asn = "65011"
  display_name = "2OnPrem"
  ip_mtu       = "MTU_1500"
  gateway_id   = oci_core_drg.FrankfurtDRG.id
  region       = var.region
}

resource "oci_core_cpe" "libre_cpe" {
  #Required
  compartment_id = var.compartment_id
  ip_address     = "3.88.217.15"
  display_name   = "LibreCPE"
  is_private     = false
}

resource "oci_core_ipsec" "ToOnpremisesVPN" {
  #Required
  compartment_id = var.compartment_id
  cpe_id         = oci_core_cpe.libre_cpe.id
  drg_id         = oci_core_drg.FrankfurtDRG.id
  static_routes  = ["192.168.0.0/16"]
  display_name   = "2onpremisesVPN"
}

data "oci_core_ipsec_connection_tunnels" "onprem_ip_sec_connection_tunnels" {
  ipsec_id = oci_core_ipsec.ToOnpremisesVPN.id
}

// default connection tunnels will be created automatically by oci
// to configure them for your needs, use this tunnel_management resource
// it is why I use datasource above to get them

resource "oci_core_ipsec_connection_tunnel_management" "ip_sec_connection_tunnels" {
  // there are only two tunnel
  count        = 2
  ipsec_id     = oci_core_ipsec.ToOnpremisesVPN.id
  tunnel_id    = data.oci_core_ipsec_connection_tunnels.onprem_ip_sec_connection_tunnels.ip_sec_connection_tunnels[count.index].id
  display_name = "Tunnel${count.index + 1}"
  // you can set whatever here, but it is recommended to use strong generated secret
  shared_secret = "sharedSecret"
  ike_version   = "V1"
  routing       = "STATIC"
}

// Your connection will be down if you use my exapmple without changes
// and not having real on-premises equipment, but all object are in place