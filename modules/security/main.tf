#-------------[Web Security Groups]-------------

resource "aws_security_group" "web_group" {
  name        = "${var.env} - Web SG"
  description = "Security Group for WEB Tier"
  tags        = merge(var.project_tags, { Name = "Web Tier SG" })
  vpc_id      = var.vpc_id
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

resource "aws_security_group" "priv_group" {
  name        = "${var.env} - EC2 SG"
  description = "Security Group for EC2 WEB Servers"
  tags        = merge(var.project_tags, { Name = "EC2 Servers SG" })
  vpc_id      = var.vpc_id
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
