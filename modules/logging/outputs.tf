
output "alb_logs_bucket_name" {
  description = "S3 bucket storing ALB access logs"
  value       = aws_s3_bucket.logs_bucket.bucket
}
output "logs_bucket_name" {
  value = aws_s3_bucket.logs_bucket.bucket
}
