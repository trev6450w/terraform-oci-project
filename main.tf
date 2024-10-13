provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# VCN and Subnet
resource "oci_core_vcn" "vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "my-vcn"
}

resource "oci_core_subnet" "subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.vcn.id
  display_name      = "my-subnet"
}

# Security List with Ingress Rules
resource "oci_core_security_list" "security_list" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "security-list-for-ubuntu-instance"

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
}

# Generate new SSH key
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content         = tls_private_key.instance_key.private_key_pem
  filename        = "${path.module}/instance_private_key.pem"
  file_permission = "0600"
}

# Ubuntu Instance
data "oci_core_images" "ubuntu_images" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
}

resource "oci_core_instance" "ubuntu_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.tenancy_ocid
  shape               = "VM.Standard.A1.Flex"
  display_name        = "ubuntu-instance"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_images.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.instance_key.public_key_openssh
  }
}

# DNS Zone
resource "oci_dns_zone" "zone" {
  compartment_id = var.tenancy_ocid
  name           = var.domain_name
  zone_type      = "PRIMARY"
}

# WWW CNAME Record
resource "oci_dns_rrset" "www_cname_record" {
  zone_name_or_id = oci_dns_zone.zone.id
  domain          = "www.${var.domain_name}"
  rtype           = "CNAME"
  items {
    domain = "www.${var.domain_name}"
    rtype  = "CNAME"
    rdata  = var.domain_name
    ttl    = 3600
  }
}

# A Record for the root domain
resource "oci_dns_rrset" "root_a_record" {
  zone_name_or_id = oci_dns_zone.zone.id
  domain          = var.domain_name
  rtype           = "A"
  items {
    domain = var.domain_name
    rtype  = "A"
    rdata  = oci_core_instance.ubuntu_instance.public_ip
    ttl    = 3600
  }
}

# Outputs
output "instance_public_ip" {
  value = oci_core_instance.ubuntu_instance.public_ip
}

output "instance_private_key" {
  value     = tls_private_key.instance_key.private_key_pem
  sensitive = true
}

output "instance_public_key" {
  value = tls_private_key.instance_key.public_key_openssh
}

output "nameservers" {
  value = oci_dns_zone.zone.nameservers
}