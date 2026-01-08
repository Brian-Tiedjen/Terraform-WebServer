#Logging

#CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/app/${var.environment}-application-logs"
  retention_in_days = 30
}

#CloudTrail logging
resource "aws_cloudtrail" "demo_cloudtrail_logs" {
  name                          = "demo-cloudtrail_logs"
  s3_bucket_name                = aws_s3_bucket.logs_bucket.bucket
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true

  depends_on = [aws_s3_bucket_policy.logs_bucket_policy]
}

#VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "vpc/${var.environment}-vpc-flow-logs"
  retention_in_days = 30
}
#setting VPC flow logs to capture REJECT traffic only to reduce costs
resource "aws_flow_log" "vpc_rejects" {
  vpc_id          = var.vpc_id
  traffic_type    = "REJECT"
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn    = aws_iam_role.vpc_flow_role.arn
}

#Create S3 bucket for backups with versioning enabled and private ACL Note:Using one bucket for ALB logs and CloudTrail logs for cost efficiency in demo
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.environment}-logs-bucket-${random_string.random_string_ec2.result}"
  tags = {
    Name = "${var.environment}_logs_bucket"
  }
  force_destroy = true


}

resource "aws_s3_bucket_public_access_block" "block_public_s3" {
  bucket                  = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "logs_bucket_versioning" {
  bucket = aws_s3_bucket.logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

#randmom string resource for S3 bucket name uniqueness
resource "random_string" "random_string_ec2" {
  length  = 6
  special = false
  upper   = false
  lower   = true
}

resource "aws_s3_bucket_ownership_controls" "logs_bucket_ownership_controls" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#S3 Bucket Policy to allow ALB to write access logs and CloudTrail logging
resource "aws_s3_bucket_policy" "logs_bucket_policy" {
  bucket = aws_s3_bucket.logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ALB access logs
      {
        Sid    = "ALBAccessLogs"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.alb_service_account.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs_bucket.arn}/alb/*"
      },

      # CloudTrail ACL check
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs_bucket.arn
      },

      # CloudTrail write access
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
