output "target_group_arn" {
  value       = aws_lb_target_group.demo_alb_group.arn
  description = "ARN of the ALB target group"
}
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.alb_public.dns_name
}

output "alb_url" {
  value       = "http://${aws_lb.alb_public.dns_name}"
  description = "URL to access the Application Load Balancer"
}

output "alb_arn" {
  value       = aws_lb.alb_public.arn
  description = "ARN of the Application Load Balancer"
}

output "demo_alb_group_arns" {
  value = [aws_lb_target_group.demo_alb_group.arn]
}
