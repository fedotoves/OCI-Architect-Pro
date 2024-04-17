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
// MySQL Database - Standard - AMD E4 - Compute
data "oci_mysql_mysql_configurations" "mysql_configurations" {
  compartment_id = var.compartment_id
  state          = "ACTIVE"
  shape_name     = "MySQL.VM.Standard.E4.1.8GB"
}

resource "oci_mysql_mysql_db_system" "mysql_db_system" {
  admin_password      = random_string.DBAdminPassword.result
  admin_username      = "admin"
  availability_domain = lookup(var.availability_domains.availability_domains[2], "name")
  compartment_id      = var.compartment_id
  configuration_id    = data.oci_mysql_mysql_configurations.mysql_configurations.configurations[0].id
  shape_name          = "MySQL.VM.Standard.E4.1.8GB"
  subnet_id           = var.db_subnet_id
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
  is_highly_available     = false
  port                    = 1521
}

// Standard DB system cost is about $5.5 per day even if it is idle, also, creation of DB takes about 90 min
// which is not reasonable for studying purposes. So I'm commenting it out, but this example was tested and works,
// will be using MySQL for studying which is way cheaper.
/*
resource "oci_database_db_system" "DBSystem" {
  availability_domain = lookup(var.availability_domains.availability_domains[2], "name")
  compartment_id = var.compartment_id
  db_home {
    database {
      admin_password = random_string.DBAdminPassword.result
      // in the video there is DB Workload set, but according to recent docs this parameter is deprecated for Base DB System
      // https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/database_db_system#db_workload
      db_workload    = "OLTP"
      db_name        = "DBSystem"
      db_backup_config {

        // Explicitly disable backups or we need to provide access to ObjectStorage
        // TODO - add auto-backup infrastructure (ObjectStorage, NAT Gateway etc.)
        auto_backup_enabled = false
      }
    }
    // over time this version may become obsolete. However while running this script you will get error that lists
    // valid DB versions
    db_version     = "19.21.0.0"
  }
  hostname        = "DBLayer"
  // I have no DenseIO shapes available and I don't have Bare Metal option to select, so going with smallest one
  shape           = "VM.Standard.E4.Flex"
  // create your own keypair and replace file content
  ssh_public_keys = tolist([file("./OCIArchitectCH2DBKey.key.pub")])
  subnet_id       = var.db_subnet_id
  cpu_core_count = 1
  //data_storage_percentage = 80
  data_storage_size_in_gb = 256
  database_edition = "STANDARD_EDITION"
  disk_redundancy = "HIGH"
  display_name = "DB System"
  license_model = "LICENSE_INCLUDED"
  node_count = 1
  // storage_volume_performance_mode = "BALANCED"
  time_zone = "UTC"
}
*/

// Takes about 2 min
// cost is $36 per day, so keeping it as example here
/*
resource "oci_database_autonomous_database" "AutonomousDB" {
  #Required
  admin_password           = random_string.DBAdminPassword.result
  compartment_id           = var.compartment_id
  cpu_core_count           = "1"
  data_storage_size_in_tbs = "1"
  db_name                  = "autonomousdb"
  db_workload              = "DW"
  display_name             = "AutonomousDB"
  license_model            = "LICENSE_INCLUDED"
}
*/
// correct way to get namespace value for bucket
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

//you need this policy to create bucket replication policy
resource "oci_identity_policy" "bucket_policy" {
  // policies are defined on tenancy level, not compartment level
  compartment_id = var.tenancy_id
  description    = "Object Storage Access for replication"
  name           = "ObjectStorageReplication"
  statements = [
    "Allow group OCI_Administrators to manage buckets in compartment OCIArchitect",
    "Allow group OCI_Administrators to manage objects in compartment OCIArchitect",
    "Allow service objectstorage-us-ashburn-1 to manage object-family in compartment OCIArchitect"
  ]
}

resource "oci_objectstorage_bucket" "DBBucket" {
  compartment_id = var.compartment_id
  name           = "DBBucket"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  depends_on     = [oci_identity_policy.bucket_policy]
}

// in video course name = backup2SJC, where SJC is San Jose region,
// but I'm using another region - FRA (Frankfurt, Germany) so name is different

resource "oci_objectstorage_replication_policy" "backupfra_policy" {
  bucket                  = oci_objectstorage_bucket.DBBucket.name
  destination_bucket_name = "ImageBucketFRA"
  destination_region_name = "eu-frankfurt-1"
  name                    = "backup2FRA"
  namespace               = data.oci_objectstorage_namespace.ns.namespace
  depends_on              = [oci_identity_policy.bucket_policy]
}