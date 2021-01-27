#-------------[Variables]-------------

variable "env" {
  description = "Environment Name"
  default     = ""
  type        = string
}

variable "free_tier" {
  description = "Please define true if you wish to stay within free-tier. Note, that Web Layer will be in Public zone!"
  type        = bool
}

variable "ec2_max_count" {
  description = "Maximum amount of EC2 instances in Web Fleet"
  default     = ""
  type        = string
}

variable "priv_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(any)
  default     = []
}

variable "web_subnet_ids" {
  description = "Web Subnet IDs"
  type        = list(any)
  default     = []
}

variable "web_group_id" {
  description = "Web Security Group ID"
  type        = string
  default     = ""
}

variable "priv_group_id" {
  description = "Private Security Group ID"
  type        = string
  default     = ""
}

variable "ssh_key" {
  description = "SSH Key Name"
  type        = string
}

variable "elb" {
  description = "Elastic Load Balancer Name"
  type        = string
}

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default     = {}
}
