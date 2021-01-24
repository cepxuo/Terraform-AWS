#-------------[Output]-------------

output "dns_name" {
  value = "http://${aws_elb.web_elb.dns_name}/"
}
