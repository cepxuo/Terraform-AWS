
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
    environment = var.environment,
    creator     = var.creator
  }
  tags = merge(var.project_tags, local.required_tags)
}

#-------------[Virtual Private Cloud]-------------

resource "aws_vpc" "universe" {
  cidr_block = "${var.cidr_base}.0.0/16"
  tags       = merge(local.tags, { Name = "VPC Universe" })
}

#-------------[Subnets]-------------
resource "aws_subnet" "web_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 10}.0/28" # /28 as we need minimal network size in Web Tier. 11 hosts available
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = merge(local.tags, { Name = "Web Public Subnet" })
  depends_on              = [aws_internet_gateway.igw]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "priv_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 20}.0/24" # /24 will be enought for 251 hosts
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = merge(local.tags, { Name = "EC2 Private Subnet" })
  map_public_ip_on_launch = (var.free_tier == true ? true : false) # Map Public IP if "free_tier" variable is set to "true"
}

#-------------[Internet Gateway]-------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.universe.id
  tags   = merge(local.tags, { Name = "Internet Gatewey" })
}

#-------------[Elastic IPs]-------------

resource "aws_eip" "nat_eip" {
  count = (var.free_tier == true ? 0 : var.subnets_count) # Create Elastic IPs for NAT Gateways if "free_tier" variable is set to "true"
  tags  = merge(local.tags, { Name = "Elastic IP for NAT GW" })
}

#-------------[NAT Gateways]-------------

resource "aws_nat_gateway" "nat" {
  count         = (var.free_tier == true ? 0 : var.subnets_count) # Create NAT Gateways if "free_tier" variable is set to "true"
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.web_subnet[count.index].id
  tags          = merge(local.tags, { Name = "NAT Gatewey" })
}

#-------------[Route Tables]-------------

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.universe.id
  tags   = merge(local.tags, { Name = "Route to IGW" })
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "nat" {
  count  = var.subnets_count
  vpc_id = aws_vpc.universe.id
  tags   = merge(local.tags, { Name = "Route to NAT" })
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = (var.free_tier == true ? aws_internet_gateway.igw.id : aws_nat_gateway.nat[count.index].id) # Route to Internet Gateway  if "free_tier" variable is set to "true", otherwise route to NAT Gateway
  }
}

resource "aws_route_table_association" "web_az" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.web_subnet[count.index].id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "priv_az" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.priv_subnet[count.index].id
  route_table_id = aws_route_table.nat[count.index].id
}

#-------------[Web Security Groups]-------------

resource "aws_security_group" "web_group" {
  name        = "Web SG"
  description = "Security Group for WEB Tier"
  tags        = merge(local.tags, { Name = "Web Tier SG" })
  vpc_id      = aws_vpc.universe.id
  dynamic "ingress" {
    for_each = var.open_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.ssh_ips
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_group" {
  name        = "EC2 SG"
  description = "Security Group for EC2 WEB Servers"
  tags        = merge(local.tags, { Name = "EC2 Servers SG" })
  vpc_id      = aws_vpc.universe.id
  depends_on  = [aws_subnet.web_subnet]
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "TCP"
    security_groups = [aws_security_group.web_group.id]
  }
  ingress {
    from_port       = "-1"
    to_port         = "-1"
    protocol        = "ICMP"
    security_groups = [aws_security_group.web_group.id]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "TCP"
    security_groups = [aws_security_group.web_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-------------[Launch Configurations]-------------

resource "aws_launch_configuration" "web_fleet" {
  name_prefix     = "web_fleet_config_"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.ec2_group.id]
  user_data       = file("web_user_data.sh")
  key_name        = var.ssh_key
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "knox" { # Fort Knox Bastion Hosts
  name_prefix     = "knox_"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_group.id]
  key_name        = var.ssh_key
  lifecycle {
    create_before_destroy = true
  }
}

#-------------[Autoscaling Groups]-------------

resource "aws_autoscaling_group" "web_fleet_asg" {
  name                 = "ASG-${aws_launch_configuration.web_fleet.name}"
  launch_configuration = aws_launch_configuration.web_fleet.name
  min_size             = 2
  max_size             = var.ec2_max_count
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [for s in data.aws_subnet_ids.priv_subnet_ids.ids : s]
  load_balancers       = [aws_elb.web_elb.name]
  tag {
    key                 = "Name"
    value               = "Web Server"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = local.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "knox_asg" { # Fort Knox Bastion Hosts ASG
  name                 = "ASG-${aws_launch_configuration.knox.name}"
  launch_configuration = aws_launch_configuration.knox.name
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1
  health_check_type    = "EC2"
  vpc_zone_identifier  = [for s in data.aws_subnet_ids.web_subnet_ids.ids : s]
  load_balancers       = [aws_elb.web_elb.name]
  tag {
    key                 = "Name"
    value               = "Fort Knox"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = local.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
#-------------[Load Balancer]-------------

resource "aws_elb" "web_elb" {
  name            = "webserver"
  security_groups = [aws_security_group.web_group.id]
  subnets         = [for s in data.aws_subnet_ids.web_subnet_ids.ids : s]
  tags            = merge(local.tags, { Name = "Web Server ELB" })
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
}
