#-------------[Variables]-------------

variable "free_tier" {
  description = "Please define true if you wish to stay within free-tier. Note, that Web Layer will be in Public zone!"
  type        = bool
  default     = false
}

variable "region" {
  description = "AWS Region"
  default     = "eu-central-1" # Frankfurt
  type        = string
}

variable "subnets_count" {
  description = "Subnets Cout"
  default     = "2"
  type        = string
}

variable "ec2_max_count" {
  description = "Maximum amount of EC2 instances in Web Fleet"
  default     = "4"
  type        = string
}

variable "cidr_base" {
  description = "CIDR base value"
  default     = "10.10"
  type        = string
}

variable "ssh_ips" {
  description = "List of IPs allowed for SSH"
  type        = list(any)
  default     = ["0.0.0.0/0"] # Put here your IP address with /32 mask
}

variable "ssh_key" {
  description = "SSH Key Name"
  type        = string
}

variable "open_ports" {
  description = "List of open ports on Web Tier"
  type        = list(any)
  default     = ["80", "443"]
}

variable "creator" {
  description = "Project creator's name"
  default     = "Sergey Kirgizov"
  type        = string
}

variable "env" {
  description = "Project environment"
  default     = "dev"
  type        = string
}

variable "project" {
  description = "Project name"
  default     = "terraform-aws"
  type        = string
}

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default     = {}
}
