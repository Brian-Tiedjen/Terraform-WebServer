output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_server_asg.name
}

output "instance_security_group_id" {
  value = var.security_group_id
}
