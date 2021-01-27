#-------------[Launch Configurations]-------------

resource "aws_launch_configuration" "web_fleet" {
  name_prefix     = "${var.env}-web_fleet_config_"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [var.priv_group_id]
  user_data       = file("web_user_data.sh")
  key_name        = var.ssh_key
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "knox" { # Fort Knox Bastion Hosts
  name_prefix     = "${var.env}-knox_"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [var.web_group_id]
  key_name        = var.ssh_key
  lifecycle {
    create_before_destroy = true
  }
}

#-------------[Autoscaling Groups]-------------

resource "aws_autoscaling_group" "web_fleet_asg" {
  name                 = "${var.env}-${aws_launch_configuration.web_fleet.name}-ASG"
  launch_configuration = aws_launch_configuration.web_fleet.name
  min_size             = 2
  max_size             = var.ec2_max_count
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [for s in var.priv_subnet_ids : s]
  load_balancers       = [var.elb]
  tag {
    key                 = "Name"
    value               = "${var.env} - Web Server"
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
  name                 = "${var.env}-${aws_launch_configuration.knox.name}-ASG"
  launch_configuration = aws_launch_configuration.knox.name
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1
  health_check_type    = "EC2"
  vpc_zone_identifier  = [for s in var.web_subnet_ids : s]
  load_balancers       = [var.elb]
  tag {
    key                 = "Name"
    value               = "${var.env} - Fort Knox"
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
