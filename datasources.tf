#-------------[Data Sources]-------------

data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet_ids" "web_subnet_ids" {
  vpc_id     = aws_vpc.universe.id
  tags       = { Name = "*Public*" }
  depends_on = [aws_subnet.web_subnet]
}

data "aws_subnet_ids" "priv_subnet_ids" {
  vpc_id     = aws_vpc.universe.id
  tags       = { Name = "*Private*" }
  depends_on = [aws_subnet.priv_subnet]
}

data "aws_availability_zones" "available" {}
