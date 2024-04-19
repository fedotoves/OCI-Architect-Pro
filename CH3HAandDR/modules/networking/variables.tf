variable "namespace" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "availability_domains" {}

output "public_subnet_id" {
  value = oci_core_subnet.PUBsubnet.id
}

output "app_subnet_id" {
  value = oci_core_subnet.AppSubnet.id
}

output "app_subnet_cidr" {
  value = local.app_subnet_cidr_block
}

output "db_subnet_id" {
  value = oci_core_subnet.DBSubnet.id
}

// network security group for file system
output "fss_nsg_id" {
  value = oci_core_network_security_group.FSS_NSG.id
}

output "vcn_id" {
  value = oci_core_vcn.VCN01.id
}

output "db_subnet_cidr" {
  value = local.DBVCN_private_subnet_cidr_block
}

output "lb_security_group_id" {
  value = oci_core_network_security_group.LBSecurityGroup.id
}

output "db_security_group_id" {
  value = oci_core_network_security_group.DB_NSG.id
}
output "web_security_group_id" {
  value = oci_core_network_security_group.WEB_Server_NSG.id
}

output "public_subnet_cidr" {
  value = local.PUB-subnet
}