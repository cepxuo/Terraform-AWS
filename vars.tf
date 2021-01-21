#-------------[Output]-------------

variable "region" {
  description = "Please enter the Region"
  default     = "eu-central-1" # Frankfurt
}

variable "ssh_ips" {
  description = "List of IPs allowed for SSH"
  type        = list(any)
  default     = ["0.0.0.0/0"] # Put here your IP address with /32 mask
}

variable "ssh_key" {
  description = "Please enter SSH Key Name"
  type        = string
}

variable "open_ports" {
  description = "List of open ports on Web Tier"
  type        = list(any)
  default     = ["80", "443"]
}

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default = {
    Creator = "Sergey Kirgizov"
    Env     = "DEV"
    Project = "Test Terraform with AWS"
  }
}
