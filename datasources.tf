#-------------[Data Sources]-------------

data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet" "web_subnets" {
  vpc_id = aws_vpc.universe.id
  filter {
    name   = "tag:Name"
    values = ["Web Public Subnet"]
  }
}

data "aws_subnet" "priv_subnets" {
  vpc_id = aws_vpc.universe.id
  filter {
    name   = "tag:Name"
    values = ["EC2 Private Subnet"]
  }
}

data "aws_availability_zones" "available" {}
