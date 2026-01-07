output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_server_asg.name
}

output "vpc_security_group_ids" {
  value = [var.security_group_id]
}
