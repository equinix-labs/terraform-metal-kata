
# set via environment variable TF_VAR_metal_project_id
variable "metal_project_id" {
  description = "Equinix Metal Project ID"
}

# set via environment variable TF_VAR_metal_auth_token
variable "metal_auth_token" {
  description = "Equinix Metal API Token"
}

variable "metal_facility" {
  description = "Equinix Metal facility. Default: ewr1"
  default     = "ewr1"
}

variable "plan" {
  description = "Instance type"
  default     = "c1.small.x86"
}

variable "lab_count" {
  description = "Number of labs"
  default     = "1"
}

variable "operating_system" {
  description = "Operating System to install across nodes"
  default     = "ubuntu_18_04"
}

variable "terraform_username" {
  description = "username running Terraform to set in host tags to help identify resource owners"
}
