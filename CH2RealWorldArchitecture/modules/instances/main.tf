locals {
  instance_shape = "VM.Standard.E4.Flex"
}

data "oci_identity_fault_domains" "fds" {

  availability_domain = lookup(var.availability_domains.availability_domains[2], "name")
  compartment_id      = var.compartment_id
}

// certificate_id was copied from OCI as certificate and was imported manually
data "oci_certificates_management_certificate" "AppLayerCert" {
  // fake value here, just to give an example, add your own certificate id
  certificate_id = "ocid1.certificate.oc1.iad.hfsdyf87ytijh87632ytiu4b3y4t"
}

resource "oci_load_balancer_load_balancer" "WebLB" {
  compartment_id = var.compartment_id
  display_name   = "WebLB"
  shape          = "flexible"
  subnet_ids     = [var.web_subnet_id, var.lb_subnet_id]
  is_private     = false
  shape_details {
    maximum_bandwidth_in_mbps = 1000
    minimum_bandwidth_in_mbps = 100
  }
}

resource "oci_load_balancer_listener" "LBListener" {
  default_backend_set_name = oci_load_balancer_backend_set.LB_Backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.WebLB.id
  name                     = "https"
  port                     = 443
  protocol                 = "TCP"

  ssl_configuration {
    certificate_ids         = [data.oci_certificates_management_certificate.AppLayerCert.id]
    verify_peer_certificate = false
  }
}

// At some point simple http listener needs to be replaced by httpS listener
// I'm leaving this one commented as example
/*
resource "oci_load_balancer_listener" "LBListener" {
  default_backend_set_name = oci_load_balancer_backend_set.LB_Backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.WebLB.id
  name                     = "http"
  port                     = 80
  protocol                 = "HTTP"
}
*/

resource "oci_load_balancer_backend" "LB_Backend" {
  // I need to add 2 web servers
  count            = 2
  backendset_name  = oci_load_balancer_backend_set.LB_Backend_set.name
  ip_address       = oci_core_instance.web_servers[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.WebLB.id
  port             = 80
}

resource "oci_load_balancer_backend_set" "LB_Backend_set" {
  health_checker {
    # protocol, port and patch for healthcheck are required
    protocol = "HTTP"
    port     = 80
    url_path = "/"
  }
  load_balancer_id = oci_load_balancer_load_balancer.WebLB.id
  session_persistence_configuration {
    cookie_name = "Ch2WebSetCookie"
  }
  name   = "WebBackendSet"
  policy = "LEAST_CONNECTIONS"
}


// here I create instances of WebServers for backend set
// You need to manually upload WebServer image to Bucket in your compartment
// and manually import it to custom images in order to query above: data "oci_core_images" "ws_image"
// will return you a valid id. Can it be automated?
resource "oci_core_instance" "web_servers" {
  //I need two, so setting count for it
  count          = 2
  compartment_id = var.compartment_id
  display_name   = "WebServer${count.index + 1}"
  //same AD as for private subnet
  availability_domain = lookup(var.availability_domains.availability_domains[1], "name")
  fault_domain        = lookup(data.oci_identity_fault_domains.fds.fault_domains[count.index], "name")
  shape               = local.instance_shape

  source_details {
    source_id   = data.oci_core_images.ws_image.images[0].id
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = var.apps_subnet_id
    assign_public_ip = false
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
}

// Web Server image should be downloaded from
// https://intoracleeli.objectstorage.us-sanjose-1.oci.customer-oci.com/p/nu0zlVevzC6Z9nyZL2ZmC94b5Na_B1lX9XNuSrcchjw5mOyjs2WqqshliZSYwzQW/n/intoracleeli/b/ImageBucketSJ/o/WebServer2
// then I manually uploaded it to the compartment to have custom image
// here I'm querying for image by display name
data "oci_core_images" "ws_image" {
  compartment_id = var.compartment_id
  display_name   = "WebServer"
  sort_by        = "TIMECREATED"
  sort_order     = "DESC"
}

resource "oci_waf_web_app_firewall_policy" "WAF" {
  compartment_id = var.compartment_id
  actions {
    name = "Preconfigured 401 Response Code Action"
    type = "RETURN_HTTP_RESPONSE"
    code = 401
  }
  display_name = "WAF"
  request_access_control {
    default_action_name = "Preconfigured 401 Response Code Action"
    rules {
      action_name = "Preconfigured 401 Response Code Action"
      name        = "NoAntarctica"
      type        = "ACCESS_CONTROL"
      // Go to Add Access Rule (according to course video and select all values. Then click "Show Advanced Controls" link
      // and you will see your condition in JMESPATH
      condition          = "i_contains(['AQ'], connection.source.geo.countryCode)"
      condition_language = "JMESPATH"
    }
  }

  request_protection {
    rules {
      action_name = "Preconfigured 401 Response Code Action"
      name        = "NoAntarctica"

      protection_capabilities {
        key     = "941140"
        version = 3
      }
      protection_capabilities {
        key     = "942270"
        version = 1
      }
      type                       = "PROTECTION"
      condition                  = "i_contains(['AQ'], connection.source.geo.countryCode)"
      condition_language         = "JMESPATH"
      is_body_inspection_enabled = true
    }
  }
}

//This is how you associate WAF with load balancer
resource "oci_waf_web_app_firewall" "waf_web_app_firewall" {
  #Required
  compartment_id             = var.compartment_id
  backend_type               = "LOAD_BALANCER"
  load_balancer_id           = oci_load_balancer_load_balancer.WebLB.id
  web_app_firewall_policy_id = oci_waf_web_app_firewall_policy.WAF.id
  display_name               = "WAF Firewall"
}

resource "oci_logging_log" "MyLBlog" {
  configuration {
    source {
      category    = "access"
      resource    = oci_load_balancer_load_balancer.WebLB.id
      service     = "loadbalancer"
      source_type = "OCISERVICE"
    }
  }
  display_name = "MyLBlog"
  log_group_id = var.log_group_id
  log_type     = "SERVICE"
}