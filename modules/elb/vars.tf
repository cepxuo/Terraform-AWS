#-------------[Variables]-------------

variable "env" {
  description = "Environment Name"
  default     = ""
  type        = string
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

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default     = {}
}
