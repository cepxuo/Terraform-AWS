#-------------[Outputs]-------------

output "vpc_id" {
  value = aws_vpc.universe.id
}

output "priv_subnet_ids" {
  value = aws_subnet.priv_subnet[*].id
}

output "web_subnet_ids" {
  value = aws_subnet.web_subnet[*].id
}
