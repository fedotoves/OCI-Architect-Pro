variable "namespace" {
  description = "The project namespace to use for unique resource naming"
  type        = string
  default     = "Chapter2"
}

variable "ssh_keypair" {
  description = "SSH keypair to use for OCI instance"
  default     = null
  type        = string
}

variable "region" {
  description = "OCI region"
  default     = "eu-frankfurt-1"
  type        = string
}

variable "tenancy_ocid" {
  default = "ocid1.tenancy.oc1..aaaaaaaaku"
}

variable "user_ocid" {
  default = "ocid1.user.oc1..aaaaaaaae3g"
}

variable "fingerprint" {
  default = "ca:4e:f3"
}

variable "private_key_path" {
  default = "<DRIVE_LETTER>:/<KEYS FOLDER>/<KEY>.pem"
}

variable "compartment_id" {
  default = "ocid1.compartment.oc1..aaaaaaaacgk"
}
