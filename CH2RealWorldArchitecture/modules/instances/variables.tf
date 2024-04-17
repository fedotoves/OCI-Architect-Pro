variable "compartment_id" {
  type = string
}

variable "apps_subnet_id" {
  type = string
}

variable "web_subnet_id" {
  type = string
}

variable "lb_subnet_id" {
  type = string
}

variable "log_group_id" {
  type = string
}

variable "availability_domains" {}

output "lb_public_ip" {
  value = oci_load_balancer_load_balancer.WebLB.ip_address_details[0].ip_address
}

output "web_server_instance_1" {
  value = oci_core_instance.web_servers[0]
}