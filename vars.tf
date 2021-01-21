#-------------[Output]-------------

variable "region" {
  description = "Please enter the Region"
  default     = "eu-central-1" # Frankfurt
}

variable "subnets_count" {
  description = "Please enter Subnets Cout"
  default     = "2"
}

variable "ec2_max_count" {
  description = "Please enter maximum amount of EC2 instances in Web Fleet"
  default     = "4"
}

variable "cidr_base" {
  description = "Please enter the CIDR base value"
  default     = "10.10"
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
