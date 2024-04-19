variable "compartment_id" {
  type = string
}

variable "availability_domains" {}

variable "db_subnet_id" {
  type = string
}

variable "tenancy_id" {
  type = string
}

output "DBPassword" {
  value = oci_mysql_mysql_db_system.mysql_db_system.admin_password
}

output "db_id" {
  value = oci_mysql_mysql_db_system.mysql_db_system.id
}