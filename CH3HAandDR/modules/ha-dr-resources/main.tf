// There is no video / instructions in this chapter on how to create web server for word press
// and separate database server
// So I'm creating custom ones myself. This is multistep process:
// Step 1 - create 2 separate compute instances with Ubuntu - web and db
// Step 2 - Using instructions install WordPress engine on first and MySql on second
// Step 3 - connect WordPress and MySql so that they can run
// Step 4 - convert configured instances to custom images - so I can delete/create them any time (don't want to waste resources
// when I'm not working on this lesson)
// Step 5 - update terraform here with custom images deployment

// I can use Cloud-Init (https://cloudinit.readthedocs.io/en/latest/) for deployment, but downloading WordPress and MySql each time for me is waste of time

// So here you will see commented code for deploying initial Ubuntu instances and working code that will
// deploy my custom images. I cannot share custom images (yet?) so if you use my solution, you need to go through all manual steps
// to get real working solution.

locals {
  instance_shape  = "VM.Standard.E5.Flex"
  web_server_name = "wp-webserver"
  db_server_name  = "wp-database"
}

data "oci_identity_fault_domains" "fds" {

  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  compartment_id      = var.compartment_id
}

// Get Ubuntu image
data "oci_core_images" "ubuntu_image" {
  compartment_id           = var.compartment_id
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
}

data "oci_core_images" "web_server_image" {
  compartment_id = var.compartment_id
  display_name   = local.web_server_name
}

data "oci_core_images" "db_server_image" {
  compartment_id = var.compartment_id
  display_name   = local.db_server_name
}

// When creating / recreating instances, IP address can change - so update your configs of WordPress and MySql for connection to be working again
// I created reserved IP for web server, database server resides in private subnet, I will assign private IP to it explicitly in code
// Create reserved IP first to use with web server. You will need it to configure MySql
// Copy it from output and use in MySqlAndWordPress setup


// oci_core_private_ips.webserver_private_ips and oci_core_vnic_attachments.webserver_vnic_attachments
// below are commented out as I use instance pool
// uncomment them if you are on the earlier stage of lesson and use single instance

/*
data "oci_core_private_ips" "webserver_private_ips" {
  vnic_id = data.oci_core_vnic_attachments.webserver_vnic_attachments.vnic_attachments[0].vnic_id
}

data "oci_core_vnic_attachments" "webserver_vnic_attachments" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.web_server.id
}
*/

data "oci_core_private_ips" "dbserver_private_ips" {
  vnic_id = data.oci_core_vnic_attachments.dbserver_vnic_attachments.vnic_attachments[0].vnic_id
}

data "oci_core_vnic_attachments" "dbserver_vnic_attachments" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.db_server.id
}

// Also, consider creating one reserved public IP manually. If you experiment with this solution and
// need to apply/ destroy it multiple times, you will need to update IP address in MySql configuration
// every time. With manual IP you can keep it the same all the time as terraform won't touch it
resource "oci_core_public_ip" "web_server_public_ip" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  // a way to explicitly assign public IP to web server is to use private IP id
  // this line is commented out as after creating load balancer, public IP is assigned to it and
  // not to web server
  // private_ip_id = data.oci_core_private_ips.webserver_private_ips.private_ips[0].id
}

// here I create instances of Ubuntu
// they are comment out as I will use custom images, which are completely configured
// for wordpress and mysql
/*
 resource "oci_core_instance" "web_servers" {
  //I need two, so setting count for it
  count          = 2
  compartment_id = var.compartment_id
  display_name   = count.index == 0? "wp-webserver":"wp-database"
  //same AD as for private subnet
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  fault_domain        = lookup(data.oci_identity_fault_domains.fds.fault_domains[count.index], "name")
  shape               = local.instance_shape

  source_details {
    source_id   = data.oci_core_images.ubuntu_image.images[0].id
    source_type = "image"
  }

  create_vnic_details {
    // Initial Ubuntu machines should be accessible to install required software
    subnet_id        = var.public_subnet_id
    assign_public_ip = true
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
  metadata = { ssh_authorized_keys = file("./OCIArchitectCH3ServersKey.key.pub")}
}
*/
// Here goes manual deployment of WordPress on wp-webserver using this instruction https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/wp-on-ubuntu/01-summary.htm
// I keep password authentication as MySql is on different server
// you need to open ports on ubuntu machines using: sudo ufw allow 3306/tcp
// port 3306 is default mysql
// use this instruction https://www.digitalocean.com/community/tutorials/how-to-allow-remote-access-to-mysql
// also this https://madeforcloud.com/2022/01/12/oci-no-route-to-host/
// can be helpful
// If you ( as I do below) put DB server inside private subnet, use PRIVATE IP of Web server while configuring MySql access
// and use db server private IP in WordPress configuration
// after instruction is done, you need to do chmod 777 on /var/www/html/wp-content (if you copied WordPress content to this folder as in instruction - if you changed it, use your folder)


// creating instances from custom preconfigured images

// this oci_core_instance.web_server instance was used before lesson reached the creation of instance pool
// it is commented out now, but you can uncomment and use it if you go through lesson step by step

/*
resource "oci_core_instance" "web_server" {
  compartment_id = var.compartment_id
  display_name   = "wp-webserver"
  //same AD as for private subnet
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  fault_domain        = lookup(data.oci_identity_fault_domains.fds.fault_domains[0], "name")
  shape               = local.instance_shape

  source_details {
    source_id   = data.oci_core_images.web_server_image.images[0].id
    source_type = "image"
  }

  create_vnic_details {
    // Initial Ubuntu machines should be accessible to install required software
    subnet_id = var.app_subnet_id
    // I need to set assign_public_ip to false, as I will use reserved IP.
    // If it is set to true, it assigns new public IP automatically
    // and reserved public IP cannot be added as there can be only one public IP
    // assigned to the instance
    assign_public_ip = false
    // set here explicitly to avoid reconfiguring of rules for db-server to allow traffic from web server
    // MySql user has this address configured in MySql
    private_ip             = "10.0.1.207"
    skip_source_dest_check = true
    nsg_ids                = [var.web_security_group_id]
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
  metadata = { ssh_authorized_keys = file("./OCIArchitectCH3ServersKey.key.pub") }
}
*/
resource "oci_core_instance" "db_server" {
  compartment_id = var.compartment_id
  display_name   = "wp-database"
  //same AD as for private subnet
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  fault_domain        = lookup(data.oci_identity_fault_domains.fds.fault_domains[1], "name")
  shape               = local.instance_shape

  source_details {
    source_id   = data.oci_core_images.db_server_image.images[0].id
    source_type = "image"
  }

  create_vnic_details {
    // Initial Ubuntu machines should be accessible to install required software
    subnet_id              = var.db_subnet_id
    assign_public_ip       = false
    skip_source_dest_check = true
    // set here explicitly to avoid reconfiguring of rules for web-server to allow traffic from db server
    private_ip = "10.0.20.166"
    nsg_ids    = [var.db_security_group_id]
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
  metadata = { ssh_authorized_keys = file("./OCIArchitectCH3ServersKey.key.pub") }
}

// VCN route table for web server to connect to db instance
resource "oci_core_route_table" "connect_to_private_subnets_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "Connect to private subnets route table"
  // for WordPress web server to connect to MySql
  route_rules {
    destination       = var.db_subnet_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = data.oci_core_private_ips.dbserver_private_ips.private_ips[0].id
  }
  route_rules {
    destination       = var.app_subnet_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = data.oci_core_private_ips.dbserver_private_ips.private_ips[0].id
  }
}

// I need those 4 resources to create file system with all options shown in video
// "Demo: High Availability Workshop Part 01
// For other commands that you need, go to OCI console, find your mount target and click on it and then click "Mount commands" button. This is manual step that you need to do
// showmount command shown in video may not be available in Ubuntu, you can install it using
// sudo apt update
// sudo apt install nfs-kernel-server
// sudo apt install nfs-common
resource "oci_file_storage_file_system" "FileSystemWordpress" {
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  compartment_id      = var.compartment_id
  display_name        = "FileSystem-wordpress"
}

resource "oci_file_storage_mount_target" "MountTargetWordpress" {
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  compartment_id      = var.compartment_id
  subnet_id           = var.db_subnet_id
  display_name        = "MountTarget-wordpress"
  nsg_ids             = [var.fss_nsg_id]
}

resource "oci_file_storage_export_set" "ExportSetWordpress" {
  mount_target_id = oci_file_storage_mount_target.MountTargetWordpress.id
  display_name    = "ExportSet-wordpress"
}

resource "oci_file_storage_export" "ExportWordpress" {
  export_set_id  = oci_file_storage_export_set.ExportSetWordpress.id
  file_system_id = oci_file_storage_file_system.FileSystemWordpress.id
  path           = "/wordpress"
}

// note showmount -e <PRIVATE_IP_OF_MOUNT_TARGET> shows file mount only after you execute commands that follow it in video
// so if you execute it before, you will see empty list
// After creation ot those resources video shows commands to run on web server. Mount command as shown doesn't work on Ubuntu
// correct one is
// sudo mount -t nfs -o nfsvers=3, <PRIVATE_IP_OF_MOUNT_TARGET>:/wordpress /mnt
// not sure if it is necessary, but I also did
// sudo ufw allow from <PRIVATE_IP_OF_MOUNT_TARGET> to any port 111
// copy command for convenience
// sudo cp -ra /var/www/html .
// for ubuntu with apache server use
// sudo systemctl start apache2
// instead of
// sudo systemctl start httpd

// Load balancer is created here, not in networking module as I need ID of web server to create it
resource "oci_load_balancer_load_balancer" "lb_wordpress" {
  compartment_id             = var.compartment_id
  display_name               = "lb_wordpress"
  shape                      = "flexible"
  subnet_ids                 = [var.public_subnet_id]
  is_private                 = false
  network_security_group_ids = [var.lb_security_group_id]
  shape_details {
    maximum_bandwidth_in_mbps = 1000
    minimum_bandwidth_in_mbps = 100
  }
  // this is commented out as I use instance pool
  // uncomment it if you are in the beginning of the lesson
  // to use single instance
  // depends_on = [ oci_core_public_ip.web_server_public_ip]
}

resource "oci_load_balancer_listener" "lb_wordpress_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.lb_wordpress_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.lb_wordpress.id
  name                     = "tcp"
  port                     = 80
  protocol                 = "TCP"
}

resource "oci_load_balancer_backend" "lb_wordpress_backend" {
  backendset_name = oci_load_balancer_backend_set.lb_wordpress_backend_set.name

  //ip_address assignment below is commented as now I use instance created for instance pool
  // this was used when I created one instance during the lesson
  ip_address       = "10.0.1.207"
  load_balancer_id = oci_load_balancer_load_balancer.lb_wordpress.id
  port             = 80
  // this is commented out as I use instance pool
  // uncomment it if you are in the beginning of the lesson
  // to use single instance
  // depends_on       = [oci_core_instance.web_server, oci_core_public_ip.web_server_public_ip]
  depends_on = [oci_core_instance_pool.instance_pool_wp_webserver]
}

resource "oci_load_balancer_backend_set" "lb_wordpress_backend_set" {
  health_checker {
    # protocol, port and patch for healthcheck are required
    protocol = "TCP"
    port     = 80
    url_path = "/"
  }
  load_balancer_id = oci_load_balancer_load_balancer.lb_wordpress.id
  session_persistence_configuration {
    cookie_name = "Ch3WebSetCookie"
  }
  name   = "WebBackendSet"
  policy = "ROUND_ROBIN"
}

resource "oci_core_instance_configuration" "instance_config_wordpress_webserver" {
  compartment_id = var.compartment_id
  display_name   = "instance-config-wordpress-webserver"
  instance_details {
    instance_type = "compute"
    launch_details {
      availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
      compartment_id      = var.compartment_id
      create_vnic_details {
        assign_public_ip = false
        // manual private IP assignment is not possible for instance pool
        // so it is commented out. I leave it here as reminder
        // private_ip             = "10.0.1.207"
        skip_source_dest_check = true
        nsg_ids                = [var.web_security_group_id]
        subnet_id              = var.app_subnet_id
      }

      metadata = { ssh_authorized_keys = file("./OCIArchitectCH3ServersKey.key.pub") }

      shape = local.instance_shape
      shape_config {
        memory_in_gbs = 6
        ocpus         = 1
      }
      source_details {
        source_type = "image"
        image_id    = data.oci_core_images.web_server_image.images[0].id
      }
    }
  }
}

resource "oci_core_instance_pool" "instance_pool_wp_webserver" {
  compartment_id            = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.instance_config_wordpress_webserver.id
  state                     = "RUNNING"
  placement_configurations {
    availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
    primary_vnic_subnets {
      subnet_id = var.app_subnet_id
    }
  }
  placement_configurations {
    availability_domain = lookup(var.availability_domains.availability_domains[1], "name")
    primary_vnic_subnets {
      subnet_id = var.app_subnet_id
    }
  }
  placement_configurations {
    availability_domain = lookup(var.availability_domains.availability_domains[2], "name")
    primary_vnic_subnets {
      subnet_id = var.app_subnet_id
    }
  }
  size         = 1
  display_name = "instance-pool-wp-webserver"
  load_balancers {
    backend_set_name = oci_load_balancer_backend_set.lb_wordpress_backend_set.name
    load_balancer_id = oci_load_balancer_load_balancer.lb_wordpress.id
    port             = 80
    vnic_selection   = "PrimaryVnic"
  }
}

resource "oci_autoscaling_auto_scaling_configuration" "auto_scaling_configuration_wp_webserver" {
  compartment_id = var.compartment_id
  display_name   = "auto-scaling-configuration-wp-webserver"
  is_enabled     = "true"

  policies {
    policy_type = "threshold"
    capacity {
      initial = "1"
      max     = "3"
      min     = "1"
    }
    rules {
      action {
        type  = "CHANGE_COUNT_BY"
        value = "1"
      }
      display_name = "wp-webserver-scale-out-rule"

      metric {
        metric_type = "CPU_UTILIZATION"

        threshold {
          operator = "GT"
          value    = "70"
        }
      }
    }
    rules {
      action {
        type  = "CHANGE_COUNT_BY"
        value = "-1"
      }

      display_name = "wp-webservers-scale-in-rule"

      metric {
        metric_type = "CPU_UTILIZATION"

        threshold {
          operator = "LT"
          value    = "1"
        }
      }
    }
    execution_schedule {
      expression = "0 15 10 ? * *"
      timezone   = "UTC"
      type       = "cron"
    }
  }
  auto_scaling_resources {
    id   = oci_core_instance_pool.instance_pool_wp_webserver.id
    type = "instancePool"
  }
}