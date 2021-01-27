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

variable "region" {
  description = "AWS Region"
  default     = ""
  type        = string
}

variable "subnets_count" {
  description = "Subnets Cout"
  default     = ""
  type        = string
}

variable "cidr_base" {
  description = "CIDR base value"
  default     = ""
  type        = string
}

variable "project_tags" {
  description = "Common Tags"
  type        = map(any)
  default     = {}
}
