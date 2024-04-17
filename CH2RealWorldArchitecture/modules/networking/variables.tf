variable "namespace" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "lb_public_ip" {}

variable "availability_domains" {}

variable "CorporateVCN_public_subnet_cidr_block" {}

output "AppsSubnetId" {
  value = oci_core_subnet.AppsSub.id
}

output "WebSubnetId" {
  value = oci_core_subnet.WebSub.id
}

output "LBSubnetId" {
  value = oci_core_subnet.LBSub.id
}

output "DBSubnetId" {
  value = oci_core_subnet.DBPrivateSub.id
}

output "log_group_id" {
  value = oci_logging_log_group.websub_log_group.id
}

output "peering_connection_to_frankfurt_id" {
  value = oci_core_remote_peering_connection.peering_connection_to_frankfurt.id
}