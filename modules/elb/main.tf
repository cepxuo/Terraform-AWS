#-------------[Load Balancer]-------------

resource "aws_elb" "elb" {
  name            = "${var.env}-Webserver-ELB"
  security_groups = [var.web_group_id]
  subnets         = [for s in var.web_subnet_ids : s]
  tags            = merge(var.project_tags, { Name = "${var.env} - Web Server ELB" })
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
