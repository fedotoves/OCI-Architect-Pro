// Subscribe to region and create compartment steps are done manually
// all var. variables are from variables.tf file

locals {
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

module "networking" {
  source               = "./modules/networking"
  namespace            = var.namespace
  compartment_id       = var.compartment_id
  availability_domains = data.oci_identity_availability_domains.ads
}

module "hadr" {
  source                = "./modules/ha-dr-resources"
  namespace             = var.namespace
  compartment_id        = var.compartment_id
  availability_domains  = data.oci_identity_availability_domains.ads
  public_subnet_id      = module.networking.public_subnet_id
  db_subnet_id          = module.networking.db_subnet_id
  fss_nsg_id            = module.networking.fss_nsg_id
  vcn_id                = module.networking.vcn_id
  db_subnet_cidr        = module.networking.db_subnet_cidr
  lb_security_group_id  = module.networking.lb_security_group_id
  app_subnet_id         = module.networking.app_subnet_id
  web_security_group_id = module.networking.web_security_group_id
  db_security_group_id  = module.networking.db_security_group_id
  public_subnet_cidr    = module.networking.public_subnet_cidr
  app_subnet_cidr       = module.networking.app_subnet_cidr
}

module "database" {
  source               = "./modules/database"
  compartment_id       = var.compartment_id
  availability_domains = data.oci_identity_availability_domains.ads
  db_subnet_id         = module.networking.db_subnet_id
  tenancy_id           = var.tenancy_ocid
}