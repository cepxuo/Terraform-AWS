#-------------[Variables]-------------

variable "env" {
  description = "Environment Name"
  default     = ""
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  default     = ""
  type        = string
}

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default     = {}
}

variable "ssh_ips" {
  description = "List of IPs allowed for SSH"
  type        = list(any)
  default     = []
}

variable "ssh_key" {
  description = "SSH Key Name"
  type        = string
}

variable "open_ports" {
  description = "List of open ports on Web Tier"
  type        = list(any)
  default     = []
}
