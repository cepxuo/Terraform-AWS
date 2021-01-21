
###############################################################################
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
## - Routes
## - Security group
## - Launch Configuration
## - Autoscaling Group
## - Load Balancer
##
## by Sergey Kirgizov, based on Denis Astahov's exemple
##
###############################################################################

#-------------[Provider AWS]-------------

provider "aws" {
  region = var.region
}

#-------------[Virtual Private Cloud]-------------

resource "aws_vpc" "universe" {
  cidr_block = "${var.cidr_base}.0.0/16"
  tags       = merge(var.project_tags, { Name = "VPC Universe" })
}

#-------------[Subnets]-------------
resource "aws_subnet" "web_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 10}.0/28" # /28 as we need minimal network size in Web Tier. 11 hosts available
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.project_tags, { Name = "Web Public Subnet" })
  depends_on              = [aws_internet_gateway.igw]
}

resource "aws_subnet" "priv_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 20}.0/24" # /24 will be enought for 251 hosts
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = merge(var.project_tags, { Name = "EC2 Private Subnet" })
  depends_on              = [aws_internet_gateway.igw] # NOT SECURE !!! Change to Nat Gateway, hence need to pay for it
  map_public_ip_on_launch = true                       # NOT SECURE !!! Change to Nat Gateway, hence need to pay for it
}

#-------------[Internet Gateway]-------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.universe.id

  tags = merge(var.project_tags, { Name = "Internet Gatewey" })
}

#-------------[Route Tables]-------------

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.universe.id
  tags   = merge(var.project_tags, { Name = "Route to IGW" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "web_az" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.web_subnet[count.index].id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "priv_az" { # NOT SECURE !!! Change to Nat Gateway, hence need to pay for it
  count          = var.subnets_count
  subnet_id      = aws_subnet.priv_subnet[count.index].id
  route_table_id = aws_route_table.web.id
}

#-------------[Web Security Groups]-------------

resource "aws_security_group" "web_group" {
  name        = "Web SG"
  description = "Security Group for WEB Tier"
  tags        = merge(var.project_tags, { Name = "Web Tier SG" })
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
  tags        = merge(var.project_tags, { Name = "EC2 Servers SG" })
  vpc_id      = aws_vpc.universe.id
  depends_on  = [aws_subnet.web_subnet]

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = [data.aws_subnet.web_subnets.cidr_block]
  }

  ingress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "ICMP"
    cidr_blocks = [data.aws_subnet.web_subnets.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [data.aws_subnet.web_subnets.cidr_block]
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
  vpc_zone_identifier  = [data.aws_subnet.priv_subnets.id]
  load_balancers       = [aws_elb.web_elb.name]
  depends_on           = [aws_subnet.priv_subnet]
  tag {
    key                 = "Name"
    value               = "Web Server"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = var.project_tags
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
  vpc_zone_identifier  = [data.aws_subnet.web_subnets.id]
  load_balancers       = [aws_elb.web_elb.name]
  depends_on           = [aws_subnet.web_subnet]
  tag {
    key                 = "Name"
    value               = "Fort Knox"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = var.project_tags
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
  subnets         = [data.aws_subnet.web_subnets.id]
  depends_on      = [aws_subnet.web_subnet]
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
  tags = merge(var.project_tags, { Name = "Web Server ELB" })
}
