output "VPC_ID" {
  value       = aws_vpc.vpc.id
  description = "The ID of the VPC created"
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.alb_public.dns_name
}
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [for subnet in aws_subnet.public_subnets : subnet.id]
}
output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [for subnet in aws_subnet.private_subnets : subnet.id]
}
output "web_instance_id" {
  description = "ID of the EC2 instance in private subnet"
  value       = aws_instance.web_server_private.id
}
output "alb_logs_bucket_name" {
  description = "S3 bucket storing ALB access logs"
  value       = aws_s3_bucket.backups_bucket.bucket
}

output "alb_url" {
  value       = "http://${aws_lb.alb_public.dns_name}"
  description = "URL to access the Application Load Balancer"
}