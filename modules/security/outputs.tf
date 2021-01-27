#-------------[Outputs]-------------

output "web_group_id" {
  value = aws_security_group.web_group.id
}

output "priv_group_id" {
  value = aws_security_group.priv_group.id
}
