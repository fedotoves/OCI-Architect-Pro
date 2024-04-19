variable "namespace" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "availability_domains" {}

variable "db_subnet_id" {}

variable "public_subnet_id" {}

variable "app_subnet_id" {}

variable "fss_nsg_id" {}

variable "vcn_id" {}

variable "db_subnet_cidr" {}

variable "lb_security_group_id" {}

output "web_public_ip" {
  value = oci_core_public_ip.web_server_public_ip.ip_address
}
variable "db_security_group_id" {}
variable "web_security_group_id" {}
variable "public_subnet_cidr" {}
variable "app_subnet_cidr" {}