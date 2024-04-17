locals {
  WebAppsVCN_cidr_block           = "10.0.0.0/16"
  WebSub_cidr_block               = "10.0.1.0/24"
  AppsSub_cidr_block              = "10.0.2.0/24"
  LBSub_cidr_block                = "10.0.3.0/24"
  DBVCN_cidr_block                = "172.16.0.0/16"
  DBVCN_private_subnet_cidr_block = "172.16.1.0/24"
  domain_name                     = "evgeniifedotov.me"
}

// Create LoadBalancer and backend set

resource "oci_core_vcn" "WebAppsVCN" {
  cidr_block     = local.WebAppsVCN_cidr_block
  display_name   = "WebAppsVCN"
  dns_label      = "WebAppsVCN"
  compartment_id = var.compartment_id
}

# public subnet to access Web facing application
resource "oci_core_subnet" "WebSub" {
  availability_domain        = lookup(var.availability_domains.availability_domains[0], "name")
  cidr_block                 = local.WebSub_cidr_block
  display_name               = "WebSub"
  dns_label                  = "WebSub"
  vcn_id                     = oci_core_vcn.WebAppsVCN.id
  route_table_id             = oci_core_vcn.WebAppsVCN.default_route_table_id
  security_list_ids          = [oci_core_vcn.WebAppsVCN.default_security_list_id, oci_core_security_list.Public.id]
  compartment_id             = var.compartment_id
  prohibit_public_ip_on_vnic = false
}
# private subnet for Web application backend
resource "oci_core_subnet" "AppsSub" {
  availability_domain        = lookup(var.availability_domains.availability_domains[1], "name")
  cidr_block                 = local.AppsSub_cidr_block
  display_name               = "AppsSub"
  dns_label                  = "AppsSub"
  vcn_id                     = oci_core_vcn.WebAppsVCN.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.Private.id]
  compartment_id             = var.compartment_id
  route_table_id             = oci_core_route_table.PrivateRT.id
}

# second subnet for LB high availability
resource "oci_core_subnet" "LBSub" {
  availability_domain = lookup(var.availability_domains.availability_domains[2], "name")
  cidr_block          = local.LBSub_cidr_block
  display_name        = "LBSub"
  dns_label           = "LBSub"
  vcn_id              = oci_core_vcn.WebAppsVCN.id
  compartment_id      = var.compartment_id
  route_table_id      = oci_core_route_table.Main_route_table.id
  security_list_ids   = [oci_core_vcn.WebAppsVCN.default_security_list_id, oci_core_security_list.Public.id]
}
# I need to keep names the same as in video. Here is security list for private subnet AppsSub
resource "oci_core_security_list" "Private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  display_name   = "Private Security List"
  ingress_security_rules {
    protocol    = "6"
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      # destination port range (doesn't require separate struct)???(what is a struct)
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/16"
    tcp_options {
      min = 22
      max = 22
    }
  }
  // from DB Layer
  ingress_security_rules {
    protocol = "6"
    source   = local.DBVCN_private_subnet_cidr_block
    tcp_options {
      // those are destination ports. Allowing all, keeping values as example and explanation
      //min = 22
      //max = 22
      source_port_range {
        #Required
        max = 1521
        min = 1521
      }
    }
  }
}

resource "oci_core_security_list" "Public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  display_name   = "Public Security List"
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      # destination port range (doesn't require separate struct)
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_internet_gateway" "IG" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  enabled        = "true"
  display_name   = "Internet Gateway"
}

resource "oci_core_route_table" "Main_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  display_name   = "Main Route Table"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.IG.id
  }
}

//To allow flow logs
resource "oci_logging_log_group" "websub_log_group" {
  compartment_id = var.compartment_id
  display_name   = "Default_Group"
  description    = "default log group"
}

// Service log is located in instances module where LoadBalancer resource is created
resource "oci_logging_log" "websub_flow_log" {
  display_name = "WebSub_all"
  log_group_id = oci_logging_log_group.websub_log_group.id
  log_type     = "CUSTOM"
}

// VCN for Database

resource "oci_core_vcn" "DBVCN" {
  cidr_block     = local.DBVCN_cidr_block
  display_name   = "DBVCN"
  dns_label      = "DBVCN"
  compartment_id = var.compartment_id
}

# private subnet for DB
resource "oci_core_subnet" "DBPrivateSub" {
  cidr_block                 = local.DBVCN_private_subnet_cidr_block
  display_name               = "DBPrivateSub"
  dns_label                  = "DBPrivateSub"
  vcn_id                     = oci_core_vcn.DBVCN.id
  prohibit_public_ip_on_vnic = true
  compartment_id             = var.compartment_id
  security_list_ids          = [oci_core_security_list.DBSecurityList.id]
  route_table_id             = oci_core_route_table.SGRouteTable.id
  depends_on                 = [oci_core_vcn.DBVCN]
}

resource "oci_core_nat_gateway" "DBNATGateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.DBVCN.id
}

data "oci_core_services" "ObjectStorageService" {
  filter {
    name   = "name"
    values = ["All IAD Services In Oracle Services Network"]
  }
}

resource "oci_core_service_gateway" "StorageServiceGateway" {
  compartment_id = var.compartment_id
  services {
    service_id = data.oci_core_services.ObjectStorageService.services.0.id
  }
  vcn_id       = oci_core_vcn.DBVCN.id
  display_name = "DB Service Gateway for Object Storage"
}

resource "oci_core_route_table" "SGRouteTable" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.DBVCN.id
  display_name   = "Service Gateway Route Table"
  route_rules {
    destination       = "all-iad-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.StorageServiceGateway.id
  }
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.DBNATGateway.id
  }
  route_rules {
    destination       = local.AppsSub_cidr_block
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_local_peering_gateway.DBLPG.id
  }
}

resource "oci_core_security_list" "DBSecurityList" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.DBVCN.id
  display_name   = "DB Security List"
  ingress_security_rules {
    protocol = "6"
    source   = local.DBVCN_cidr_block
    tcp_options {
      max = 22
      min = 22
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "177.16.0.0/16"
    icmp_options {
      type = 3
    }
  }
  // to DB Layer
  ingress_security_rules {
    protocol = "6"
    source   = local.AppsSub_cidr_block
    tcp_options {
      max = 1521
      min = 1521
    }
  }

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
}

resource "oci_core_local_peering_gateway" "DBLPG" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.DBVCN.id
}

resource "oci_core_local_peering_gateway" "WebAppsLPG" {
  #Required
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  peer_id        = oci_core_local_peering_gateway.DBLPG.id
}

// Route table for local peering gateway
resource "oci_core_route_table" "PrivateRT" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.WebAppsVCN.id
  display_name   = "Local Peering Gateway Route Table"
  route_rules {
    destination       = local.DBVCN_private_subnet_cidr_block
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_local_peering_gateway.WebAppsLPG.id
  }
}

// DNS

resource "oci_dns_zone" "CH2_zone" {
  compartment_id = var.compartment_id
  // My domain, bought it at GoDaddy for $ 7.70 for a year
  name      = local.domain_name
  zone_type = "PRIMARY"
}

resource "oci_dns_rrset" "CH2_rrset" {
  #Required
  domain          = oci_dns_zone.CH2_zone.name
  rtype           = "A"
  zone_name_or_id = oci_dns_zone.CH2_zone.id
  compartment_id  = var.compartment_id
  items {
    domain = oci_dns_zone.CH2_zone.name
    rtype  = "A"
    rdata  = var.lb_public_ip
    ttl    = 3600
  }
}

// SSL Cert
// I bought mine for 5 years for $20 at comodo
// GoDaddy cert is $209 for 3 years.
// When doing verification by adding CNAME record don't forget to click "Publish Changes" after adding record
// And don't forget to delete verification record after


// Seems that you cannot create certificate from terraform at least on oci provider version 5.26
// according to https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/certificates_management_certificate
// find this line : cert_chain_pem - (Required when config_type=IMPORTED) in doc
// but I'm getting error
// expected certificate_config.0.config_type to be one of [ISSUED_BY_INTERNAL_CA MANAGED_EXTERNALLY_ISSUED_BY_INTERNAL_CA]

// I'm adding certificate manually to my Infrastructure


// Ashburn is my home region (in video sanjose is home), so name differs
resource "oci_core_drg" "AshburnDRG" {
  compartment_id = var.compartment_id
  display_name   = "AshburnDRG"
}

resource "oci_core_drg_attachment" "AshburnDRG_attachment" {
  drg_id = oci_core_drg.AshburnDRG.id
  network_details {
    id   = oci_core_vcn.DBVCN.id
    type = "VCN"
  }
}

resource "oci_core_remote_peering_connection" "peering_connection_to_frankfurt" {
  compartment_id = var.compartment_id
  drg_id         = oci_core_drg.AshburnDRG.id
  display_name   = "2Frankfurt"
}
// creating separate route table instead of adding rule to existing one
// querying for route table and modifying rules can be time consuming
resource "oci_core_route_table" "DRGAshPeeringRouteTable" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.DBVCN.id
  display_name   = "DRG Ash Peering Route Table"
  route_rules {
    destination       = var.CorporateVCN_public_subnet_cidr_block
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.AshburnDRG.id
  }
}