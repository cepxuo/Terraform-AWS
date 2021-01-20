#-------------[Output]-------------

output "dns_name" {
  value = aws_elb.web_elb.dns_name
}
