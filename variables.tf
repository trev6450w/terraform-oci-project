variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}


# Change default to whatever you want
variable "domain_name" {
  type        = string
  description = "The domain name for DNS configuration"
  default     = "trev.lol" 
}
