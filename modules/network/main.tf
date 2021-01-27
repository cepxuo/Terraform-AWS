#-------------[Virtual Private Cloud]-------------

resource "aws_vpc" "universe" {
  cidr_block = "${var.cidr_base}.0.0/16"
  tags       = merge(var.project_tags, { Name = "${var.env} - VPC Universe" })
}

#-------------[Subnets]-------------
resource "aws_subnet" "web_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 10}.0/28" # /28 as we need minimal network size in Web Tier. 11 hosts available
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = merge(var.project_tags, { Name = "${var.env} - Web Public Subnet ${count.index + 1}" })
  depends_on              = [aws_internet_gateway.igw]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "priv_subnet" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.universe.id
  cidr_block              = "${var.cidr_base}.${count.index + 20}.0/24" # /24 will be enought for 251 hosts
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = merge(var.project_tags, { Name = "${var.env} - EC2 Private Subnet ${count.index + 1}" })
  map_public_ip_on_launch = (var.free_tier == true ? true : false) # Map Public IP if "free_tier" variable is set to "true"
}

#-------------[Internet Gateway]-------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.universe.id
  tags   = merge(var.project_tags, { Name = "${var.env} - Internet Gatewey" })
}

#-------------[Elastic IPs]-------------

resource "aws_eip" "nat_eip" {
  count = (var.free_tier == true ? 0 : var.subnets_count) # Create Elastic IPs for NAT Gateways if "free_tier" variable is set to "true"
  tags  = merge(var.project_tags, { Name = "${var.env} - Elastic IP ${count.index + 1} for NAT GW" })
}

#-------------[NAT Gateways]-------------

resource "aws_nat_gateway" "nat" {
  count         = (var.free_tier == true ? 0 : var.subnets_count) # Create NAT Gateways if "free_tier" variable is set to "true"
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.web_subnet[count.index].id
  tags          = merge(var.project_tags, { Name = "${var.env} - NAT Gateway ${count.index + 1}" })
}

#-------------[Route Tables]-------------

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.universe.id
  tags   = merge(var.project_tags, { Name = "${var.env} - Route to IGW" })
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "nat" {
  count  = var.subnets_count
  vpc_id = aws_vpc.universe.id
  tags   = merge(var.project_tags, { Name = "${var.env} - Route ${count.index + 1} to NAT" })
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
