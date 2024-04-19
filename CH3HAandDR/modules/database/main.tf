resource "random_string" "DBAdminPassword" {
  length = 16
  // numbers below define number of characters for password so that it passes validation.
  min_numeric = 2
  min_lower   = 1
  min_upper   = 2
  // to satisfy password requirements the database admin password should contain only: alphanumeric, hyphen(-), underscore(_), pound(#).
  // I set override_special to 0
  special          = true
  override_special = "-_#"
  min_special      = 2
}

data "oci_mysql_mysql_configurations" "mysql_configurations" {
  compartment_id = var.compartment_id
  state          = "ACTIVE"
  shape_name     = "MySQL.VM.Standard.E3.1.8GB"
}

resource "oci_mysql_mysql_db_system" "mysql_db_system" {
  admin_password      = random_string.DBAdminPassword.result
  admin_username      = "admin"
  availability_domain = lookup(var.availability_domains.availability_domains[0], "name")
  compartment_id      = var.compartment_id
  // need to use second element [1] instead of [0] as High Availability is second in the list
  configuration_id = data.oci_mysql_mysql_configurations.mysql_configurations.configurations[1].id
  shape_name       = "MySQL.VM.Standard.E3.1.8GB"
  subnet_id        = var.db_subnet_id
  display_name     = "mysql-wordpress"
  backup_policy {
    is_enabled = false
    pitr_policy {
      is_enabled = false
    }
    retention_in_days = 1
  }
  //required if you create new DB
  data_storage_size_in_gb = 50
  hostname_label          = "mysql"
  is_highly_available     = true
  port                    = 1521
}

// You need to repeat manual steps from video to set up
// wordpress db