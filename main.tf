
###############################################################################
##
## Highly Available Web Server with Blue/Green deployment and PHP 7.4 support
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
  region = "eu-central-1" # Frankfurt
}

#-------------[Virtual Private Cloud]-------------

resource "aws_vpc" "universe" {
  cidr_block = "10.10.0.0/16"
  tags       = merge(var.project_tags, { Name = "VPC Universe" })
}

#-------------[Subnets]-------------
resource "aws_subnet" "web_subnet_az1" {
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = merge(var.project_tags, { Name = "Web Public Subnet in AZ1" })
  depends_on              = [aws_internet_gateway.igw]
}

resource "aws_subnet" "web_subnet_az2" {
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = merge(var.project_tags, { Name = "Web Public Subnet in AZ2" })
  depends_on              = [aws_internet_gateway.igw]
}

resource "aws_subnet" "priv_subnet_az1" {
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "10.10.11.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = merge(var.project_tags, { Name = "EC2 Private Subnet in AZ1" })
  depends_on              = [aws_internet_gateway.igw] # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
  map_public_ip_on_launch = true                       # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
}

resource "aws_subnet" "priv_subnet_az2" {
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "10.10.12.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags                    = merge(var.project_tags, { Name = "EC2 Private Subnet in AZ2" })
  depends_on              = [aws_internet_gateway.igw] # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
  map_public_ip_on_launch = true                       # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
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

resource "aws_route_table_association" "web_az1" {
  subnet_id      = aws_subnet.web_subnet_az1.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "web_az2" {
  subnet_id      = aws_subnet.web_subnet_az2.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "priv_az1" { # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
  subnet_id      = aws_subnet.priv_subnet_az1.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "priv_az2" { # NOT SECURE !!! Change to Nat Gateway,  hence need to pay for it
  subnet_id      = aws_subnet.priv_subnet_az2.id
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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = [aws_subnet.web_subnet_az1.cidr_block, aws_subnet.web_subnet_az2.cidr_block]
  }

  ingress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "ICMP"
    cidr_blocks = [aws_subnet.web_subnet_az1.cidr_block, aws_subnet.web_subnet_az2.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [aws_subnet.web_subnet_az1.cidr_block, aws_subnet.web_subnet_az2.cidr_block]
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
  max_size             = 4
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_subnet.priv_subnet_az1.id, aws_subnet.priv_subnet_az2.id]
  load_balancers       = [aws_elb.web_elb.name]
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
  vpc_zone_identifier  = [aws_subnet.web_subnet_az1.id, aws_subnet.web_subnet_az2.id]
  load_balancers       = [aws_elb.web_elb.name]
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
  subnets         = [aws_subnet.web_subnet_az1.id, aws_subnet.web_subnet_az2.id]
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
