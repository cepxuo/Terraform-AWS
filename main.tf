
################################################################################
##
## Highly Available Web Server with Blue/Green deployment and PHP 7.4 support
##
## Webpage is stored in https://github.com/cepxuo/webpage.git repository
##
## We will create the following infrastructure:
##
## - VPC
## - Subnets
## - Internet Gateway
## - NAT Gateways with Elastic IPs
## - Routes
## - Security group
## - Launch Configuration
## - Autoscaling Group
## - Load Balancer
##
## by Sergey Kirgizov, based on Denis Astahov's example
##
################################################################################

#-------------[Provider AWS]-------------

provider "aws" {
  region = var.region
}

#-------------[Locals]-------------

locals {
  required_tags = {
    project     = var.project,
    environment = var.env,
    creator     = var.creator
  }
  tags = merge(var.project_tags, local.required_tags)
}

#-------------[Netwokr Layer]-------------

module "vpc" {
  source        = "./modules/network"
  env           = var.env
  free_tier     = var.free_tier
  region        = var.region
  subnets_count = var.subnets_count
  cidr_base     = var.cidr_base
  project_tags  = local.tags
}

#-------------[Security Layer]-------------

module "security_groups" {
  source       = "./modules/security"
  depends_on   = [module.vpc.web_subnet_ids, module.vpc.priv_subnet_ids, module.vpc.vpc_id]
  env          = var.env
  vpc_id       = module.vpc.vpc_id
  project_tags = local.tags
  ssh_ips      = var.ssh_ips
  ssh_key      = var.ssh_key
  open_ports   = var.open_ports
}

#-------------[Autoscaling Groups Layer]-------------

module "autoscaling_groups" {
  source          = "./modules/asg"
  depends_on      = [module.security_groups.priv_group, module.security_groups.web_group]
  env             = var.env
  free_tier       = var.free_tier
  ec2_max_count   = var.ec2_max_count
  priv_subnet_ids = module.vpc.priv_subnet_ids
  web_subnet_ids  = module.vpc.web_subnet_ids
  priv_group_id   = module.security_groups.priv_group_id
  web_group_id    = module.security_groups.web_group_id
  ssh_key         = var.ssh_key
  elb             = module.elb.elb_name
  project_tags    = local.tags
}

#-------------[Elastic Load Balancer Layer]-------------

module "elb" {
  source         = "./modules/elb"
  depends_on     = [module.vpc.web_subnet_ids, module.security_groups.web_group]
  env            = var.env
  web_subnet_ids = module.vpc.web_subnet_ids
  web_group_id   = module.security_groups.web_group_id
  project_tags   = local.tags
}
