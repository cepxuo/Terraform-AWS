#-------------[Output]-------------

output "dns_name" {
  value = "http://${module.elb.elb_dns_name}/"
}
