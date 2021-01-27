#-------------[Outputs]-------------

output "web_fleet_lc" {
  value = aws_launch_configuration.web_fleet.id
}

output "knox_lc" {
  value = aws_launch_configuration.knox.id
}

output "web_fleet_asg" {
  value = aws_autoscaling_group.web_fleet_asg.id
}

output "knox_asg" {
  value = aws_autoscaling_group.knox_asg.id
}
