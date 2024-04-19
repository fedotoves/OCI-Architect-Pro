locals {
  VCN01_cidr_block                = "10.0.0.0/16"
  PUB-subnet                      = "10.0.0.0/24"
  DBVCN_private_subnet_cidr_block = "10.0.20.0/24"
  app_subnet_cidr_block           = "10.0.1.0/24"
}

resource "oci_core_vcn" "VCN01" {
  cidr_block     = local.VCN01_cidr_block
  display_name   = "VCN01"
  dns_label      = "VCN01"
  compartment_id = var.compartment_id
}

# public subnet to access Web facing application
// it was also used for webserver in the video, but after creating load balancer new subnet will be created for instance pool
// so I will create separate subnet for web servers to use it in instance pool later
resource "oci_core_subnet" "PUBsubnet" {
  cidr_block                 = local.PUB-subnet
  display_name               = "PUB-subnet"
  dns_label                  = "PUBsub"
  vcn_id                     = oci_core_vcn.VCN01.id
  compartment_id             = var.compartment_id
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.main_route_table.id
  security_list_ids          = [oci_core_vcn.VCN01.default_security_list_id, oci_core_security_list.Public.id]
}

# public subnet for web application
resource "oci_core_subnet" "AppSubnet" {
  cidr_block                 = local.app_subnet_cidr_block
  display_name               = "APP-subnet"
  dns_label                  = "APPsubnet"
  vcn_id                     = oci_core_vcn.VCN01.id
  prohibit_public_ip_on_vnic = true
  compartment_id             = var.compartment_id
  route_table_id             = oci_core_route_table.main_route_table.id
  security_list_ids          = [oci_core_vcn.VCN01.default_security_list_id, oci_core_security_list.Public.id]
  depends_on                 = [oci_core_subnet.PUBsubnet]
}

# private subnet for DB
resource "oci_core_subnet" "DBSubnet" {
  cidr_block                 = local.DBVCN_private_subnet_cidr_block
  display_name               = "DB-subnet"
  dns_label                  = "DBsubnet"
  vcn_id                     = oci_core_vcn.VCN01.id
  prohibit_public_ip_on_vnic = true
  compartment_id             = var.compartment_id
  // availability_domain        = lookup(var.availability_domains.availability_domains[0], "name")
  route_table_id    = oci_core_route_table.main_route_table.id
  security_list_ids = [oci_core_vcn.VCN01.default_security_list_id, oci_core_security_list.Private.id]
}

resource "oci_core_network_security_group" "WEB_Server_NSG" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "WEB_Server_NSG"
}
// for lb
resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule1" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.WEB_Server_NSG.id
  source_type               = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.LBSecurityGroup.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {

    destination_port_range {
      max = 80
      min = 80
    }
    source_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule2" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.LBSecurityGroup.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    source_port_range {
      max = 80
      min = 80
    }
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

// for db
resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule3" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6

  source           = oci_core_network_security_group.WEB_Server_NSG.id
  source_type      = "NETWORK_SECURITY_GROUP"
  destination      = oci_core_network_security_group.DB_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
  stateless        = false
  tcp_options {
    destination_port_range {
      max = 3306
      min = 3306
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule4" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.DB_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    source_port_range {
      max = 3306
      min = 3306
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule5" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6

  source           = oci_core_network_security_group.WEB_Server_NSG.id
  source_type      = "NETWORK_SECURITY_GROUP"
  destination      = oci_core_network_security_group.FSS_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
  stateless        = false
  tcp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule6" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    source_port_range {
      max = 111
      min = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule7" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.WEB_Server_NSG.id
  source_type               = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.FSS_NSG.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {
    destination_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule8" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    source_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "WEB_Server_NSG_SecRule9" {
  network_security_group_id = oci_core_network_security_group.WEB_Server_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  stateless   = false
  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group" "DB_NSG" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "DB_NSG"
}

resource "oci_core_network_security_group_security_rule" "DB_NSG_SecRule1" {
  network_security_group_id = oci_core_network_security_group.DB_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.DB_NSG.id
  source_type               = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.WEB_Server_NSG.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {
    destination_port_range {
      max = 3306
      min = 3306
    }
  }
}

resource "oci_core_network_security_group_security_rule" "DB_NSG_SecRule2" {
  network_security_group_id = oci_core_network_security_group.DB_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.WEB_Server_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    source_port_range {
      max = 3306
      min = 3306
    }
  }
}


resource "oci_core_security_list" "Public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "Public Security List"
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  egress_security_rules {
    protocol    = "6"
    destination = local.app_subnet_cidr_block
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

resource "oci_core_security_list" "Private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "Private Security List"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 3306
      max = 3306
    }
  }
  // for FileMount
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 2048
      max = 2050
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 111
      max = 111
    }
  }

  egress_security_rules {
    protocol = "6"

    tcp_options {
      min = 111
      max = 111
    }
    destination = local.app_subnet_cidr_block
  }

  egress_security_rules {
    protocol = "6"

    tcp_options {
      min = 2048
      max = 2050
    }
    destination = local.app_subnet_cidr_block
  }

  egress_security_rules {
    protocol = "6"

    tcp_options {
      min = 3306
      max = 3306
    }
    destination = local.app_subnet_cidr_block
  }

  // for load balancer
  ingress_security_rules {
    protocol = "6"
    source   = local.PUB-subnet
    tcp_options {
      min = 80
      max = 80
    }
  }
  egress_security_rules {
    protocol = "6"
    tcp_options {
      min = 80
      max = 80
    }
    destination = local.PUB-subnet
  }
}

resource "oci_core_internet_gateway" "IG" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  enabled        = "true"
  display_name   = "Internet Gateway"
}

resource "oci_core_route_table" "main_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "Main Route Table"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.IG.id
  }
}


// In the video there are other security groups already present.
// Where are they from? It is not explained. Doesn't seem to be from Chapter 2, as names are different and VCNs
// are also different. So full set of rules is unknown. Will try to add rules that I can understand from video
resource "oci_core_network_security_group" "FSS_NSG" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "FSS_NSG"
}

// two following rules are for TCP, protocol = 6
resource "oci_core_network_security_group_security_rule" "tcp1_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    destination_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "tcp2_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "INGRESS"
  protocol                  = 6

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  tcp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

// two following rules are for UDP, protocol = 17
resource "oci_core_network_security_group_security_rule" "udp1_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "INGRESS"
  protocol                  = 17

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  udp_options {
    destination_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "udp2_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "INGRESS"
  protocol                  = 17

  source      = oci_core_network_security_group.FSS_NSG.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false
  udp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

// It is not shown in the video - only ingress rules were shown - but you also need stateful egress for TCP source ports 111, 2048, 2049, and 2050, and UDP source port 111
// two following rules are for TCP, protocol = 6
resource "oci_core_network_security_group_security_rule" "tcp3_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6

  source           = oci_core_network_security_group.FSS_NSG.id
  source_type      = "NETWORK_SECURITY_GROUP"
  stateless        = false
  destination      = oci_core_network_security_group.WEB_Server_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "tcp4_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "EGRESS"
  protocol                  = 6

  source           = oci_core_network_security_group.FSS_NSG.id
  source_type      = "NETWORK_SECURITY_GROUP"
  stateless        = false
  destination      = oci_core_network_security_group.WEB_Server_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "udp3_security_rule" {
  network_security_group_id = oci_core_network_security_group.FSS_NSG.id
  direction                 = "EGRESS"
  protocol                  = 17

  source           = oci_core_network_security_group.FSS_NSG.id
  source_type      = "NETWORK_SECURITY_GROUP"
  stateless        = false
  destination      = oci_core_network_security_group.WEB_Server_NSG.id
  destination_type = "NETWORK_SECURITY_GROUP"
  udp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

// for Load Balancer
resource "oci_core_network_security_group" "LBSecurityGroup" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.VCN01.id
  display_name   = "LB_NSG"
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule1" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "INGRESS"
  protocol                  = 6
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule2" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "INGRESS"
  protocol                  = 6
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      max = 443
      min = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule3" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "EGRESS"
  protocol                  = 6
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule4" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "EGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.LBSecurityGroup.id
  source_type               = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.WEB_Server_NSG.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
    source_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule5" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "INGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.WEB_Server_NSG.id
  source_type               = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {
    source_port_range {
      max = 80
      min = 80
    }
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_security_rule6" {
  network_security_group_id = oci_core_network_security_group.LBSecurityGroup.id
  direction                 = "INGRESS"
  protocol                  = 6
  source                    = oci_core_network_security_group.LBSecurityGroup.id
  source_type               = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.LBSecurityGroup.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  tcp_options {
    source_port_range {
      max = 80
      min = 80
    }
    destination_port_range {
      max = 80
      min = 80
    }
  }
}
