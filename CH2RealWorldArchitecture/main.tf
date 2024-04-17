// Subscribe to region and create compartment steps are done manually
// all var. variables are from variables.tf file

locals {
  web_server = module.instances.web_server_instance_1
  // those are for second (Frankfurt) region
  CorporateVCN_cidr_block               = "172.17.0.0/16"
  CorporateVCN_public_subnet_cidr_block = "172.17.0.0/24"
  // using /24 as in video gives error:
  // The requested CIDR 172.17.1.0/24 is invalid: CIDR IP 172.17.1.0 does not match network IP 172.17.0.0.
  // so I'm using /30
  CorporateVCN_private_subnet_cidr_block = "172.17.1.0/30"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

module "frankfurt" {
  source                                 = "./../CH2RealWorldArchitectureSecondRegion"
  peering_connection_to_frankfurt_id     = module.networking.peering_connection_to_frankfurt_id
  CorporateVCN_cidr_block                = local.CorporateVCN_cidr_block
  CorporateVCN_private_subnet_cidr_block = local.CorporateVCN_private_subnet_cidr_block
  CorporateVCN_public_subnet_cidr_block  = local.CorporateVCN_public_subnet_cidr_block
}

module "networking" {
  source                                = "./modules/networking"
  namespace                             = var.namespace
  compartment_id                        = var.compartment_id
  availability_domains                  = data.oci_identity_availability_domains.ads
  lb_public_ip                          = module.instances.lb_public_ip
  CorporateVCN_public_subnet_cidr_block = local.CorporateVCN_public_subnet_cidr_block
}

module "instances" {
  source               = "./modules/instances"
  compartment_id       = var.compartment_id
  availability_domains = data.oci_identity_availability_domains.ads
  apps_subnet_id       = module.networking.AppsSubnetId
  web_subnet_id        = module.networking.WebSubnetId
  lb_subnet_id         = module.networking.LBSubnetId
  log_group_id         = module.networking.log_group_id
}

module "database" {
  source               = "./modules/database"
  compartment_id       = var.compartment_id
  availability_domains = data.oci_identity_availability_domains.ads
  db_subnet_id         = module.networking.DBSubnetId
  tenancy_id           = var.tenancy_ocid
  // depends on Frankfurt as we need bucket in FRA before DB creation for replication
  depends_on = [module.networking, module.frankfurt]
}

// Bastion can be used for DBs and Instances and requires target_resource_id
// so I'm creating it here to avoid cyclomatic dependency between networking and instances module as I need
// module.networking.WebSubnetId and local.web_server which references variable from Instances module
// putting bastion inside module creates the cycle when creating bastion session
resource "oci_bastion_bastion" "DBBastion" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_id
  target_subnet_id = module.networking.AppsSubnetId

  // You need the IP of your machine. It is usually dynamic, so before accessing bastion verify it here https://whatismyipaddress.com/
  // and update if necessary
  // or you can use 0.0.0.0/0 to allow anyone to connect which is very unsecure
  client_cidr_block_allow_list = ["76.146.36.226/32"]
  name                         = "DBBastion"
}

//you need this policy to create bastion session
resource "oci_identity_policy" "bastion_session_policy" {
  // policies are defined on tenancy level, not compartment level
  compartment_id = var.tenancy_ocid
  description    = "Bastion Sessions"
  name           = "BastionSessions"
  statements = [
    "Allow group OCI_Administrators to manage bastion-family in tenancy",
    "Allow group OCI_Administrators to manage virtual-network-family in tenancy",
    "Allow group OCI_Administrators to read instance-family in tenancy",
    "Allow group OCI_Administrators to read instance-agent-plugins in tenancy",
    "Allow group OCI_Administrators to inspect work-requests in tenancy"
  ]
}
/*

// usually you create session manually for particular task,
// but to give an example, I'm creating it here.
// by default session is valid for 30 min
// cannot replicate access to DB node as in the video because of target_resource_id parameter (see comment below in code)
// but I can do the same for WebServer, it should be ok for learning purposes
// output will be a ssh command to use for connection

// strange thing here. you don't need target_resource_id when creating port forwarding session using
// UI as in video, but in terraform it is required
resource "oci_bastion_session" "DBBastionSession" {
  bastion_id = oci_bastion_bastion.DBBastion.id
  key_details {
    // You need to create the key manually
    public_key_content = file("./OCIArchitectCH2BastionSession.key.pub")
  }
  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_port               = 80
    target_resource_private_ip_address = local.web_server.private_ip
    // for MySql go to mysql db and click "Endpoints", you will see endpoint with IP address
    // target_resource_id param kills the purpose of port forwarding session, as it requires something like instance
    // there is no instance to connect to in MySql, but there is an endpoint with port 1521
    // in UI you can create port forwarding with IP and port only
    // so, to test if it works, I'm creating port forwarding to one of WebServer instances for port 80,
    //so that you can go to localhost:80 and see the website
    target_resource_id = local.web_server.id
  }
  display_name = "access2webserver"
  key_type     = "PUB"
  //you must have policies in place before creating session
  depends_on = [oci_bastion_bastion.DBBastion, oci_identity_policy.bastion_session_policy]
}

// in case of "bad permissions" error do chmod 400 on the key file
output "ssh_session" {
  value = oci_bastion_session.DBBastionSession.ssh_metadata
}

*/