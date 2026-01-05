#Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "newest_linux_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#Get ALB service account for S3 bucket policy
data "aws_elb_service_account" "alb_service_account" {}

#Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

#Get current AWS account ID
data "aws_caller_identity" "current" {}

#Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
    Environment = "AWS-Terraform"
  }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value.cidr)
  availability_zone = each.value.az

  tags = {
    Name = each.key
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value.cidr + 100)
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = {
    Name = each.key
  }
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "demo_public_route_table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_nat_gateway.nat_gateway]
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "demo_private_route_table"
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_internet_gateway"
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "demo_nat_gateway_eip"
  }
}

#Create NAT Gateway - only using one for cost and demo purposes
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_internet_gateway.internet_gateway]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "demo_nat_gateway"
  }
}

#Security Group for EC2 Instance
resource "aws_security_group" "ec2_instance_sg" {
  name        = "ec2_instance_sg"
  description = "Security group for EC2 instance in private subnet"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#AutoScaling Group and Launch Template

#Launch Template for AutoScaling Group
resource "aws_launch_template" "web_server_lt" {
  name_prefix            = "demo-web-server-asg-"
  image_id               = data.aws_ami.newest_linux_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }


  lifecycle {
    create_before_destroy = true
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y amazon-cloudwatch-agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-linux -s
              amazon-linux-extras enable nginx1
              sudo yum install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx

              cat <<HTML > /usr/share/nginx/html/index.html
              <!DOCTYPE html>
              <html>
              <head>
                <title>Terraform ALB Demo - AutoScaling</title>
              </head>
              <body>
                <h1>It works! </h1>
                <p>Deployed with Terraform</p>
                <p>Private AutoScaling EC2 behind a public ALB</p>
              </body>
              </html>
              HTML
              EOF
  )
}

#AutoScaling Group
resource "aws_autoscaling_group" "web_server_asg" {
  name                      = "demo-web-server-asg"
  vpc_zone_identifier       = [for subnet in aws_subnet.private_subnets : subnet.id]
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.demo_alb_group.arn]
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  termination_policies      = ["OldestInstance", "ClosestToNextInstanceHour"]
  protect_from_scale_in     = true

  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = aws_launch_template.web_server_lt.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  tag {
    key                 = "Name"
    value               = "WebServerAutoScalingInstance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-70-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

#Replaced by AutoScaling Group below
/*
#Create EC2 instance in private subnet
resource "aws_instance" "web_server_private" {
  ami                    = data.aws_ami.newest_linux_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnets["private_subnet_1"].id
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y amazon-cloudwatch-agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-linux -s
              amazon-linux-extras enable nginx1
              sudo yum install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx

              cat <<HTML > /usr/share/nginx/html/index.html
              <!DOCTYPE html>
              <html>
              <head>
                <title>Terraform ALB Demo</title>
              </head>
              <body>
                <h1>It works! </h1>
                <p>Deployed with Terraform</p>
                <p>Private EC2 behind a public ALB</p>
              </body>
              </html>
              HTML
              EOF

  tags = {
    "Name" = "WebServerInstancePrivate"
  }
}
*/

#Create Application Load Balancer
resource "aws_lb" "alb_public" {
  name               = "demo-alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public_group.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]
  depends_on         = [aws_security_group.alb_public_group]

  access_logs {
    bucket  = aws_s3_bucket.logs_bucket.bucket
    prefix  = "alb"
    enabled = true
  }
  tags = {
    name = "demo-alb-public"
  }
}


#Create ALB Target Group
resource "aws_lb_target_group" "demo_alb_group" {
  name        = "demo-alb-target-group"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "demo-alb-target-group"
  }
}
/*
#Attach EC2 instance to ALB target group
resource "aws_lb_target_group_attachment" "web_instance" {
  target_group_arn = aws_lb_target_group.demo_alb_group.arn
  target_id        = aws_instance.web_server_private.id
  port             = 80
}
*/

#Create ALB listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb_public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_alb_group.arn
  }
}

#Security Group for ALB
resource "aws_security_group" "alb_public_group" {
  name        = "alb_public_sg"
  description = "Security group for public ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create S3 bucket for backups with versioning enabled and private ACL Note:Using one bucket for ALB logs and CloudTrail logs for cost efficiency in demo
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "demo-logs-bucket-${random_string.random_string_ec2.result}"
  tags = {
    Name = "demo_logs_bucket"
  }
  force_destroy = true

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

#Alarms

# Alarms removed for EC2 instance as replaced by AutoScaling Group
/*
#create CloudWatch Metric Alarm for high CPU utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 90

  dimensions = {
    InstanceId = aws_instance.web_server_private.id
  }
}


#Status check alarm
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name          = "ec2-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1

  dimensions = {
    InstanceId = aws_instance.web_server_private.id
  }
}
*/

#ALB 5xx errors alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 1

  dimensions = {
    LoadBalancer = aws_lb.alb_public.arn_suffix
  }
}

#ALB Unhealthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  dimensions = {
    TargetGroup  = aws_lb_target_group.demo_alb_group.arn_suffix
    LoadBalancer = aws_lb.alb_public.arn_suffix
  }
}

#Logging

#CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/app/demo-application-logs"
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
  name              = "vpc/demo-vpc-flow-logs"
  retention_in_days = 30
}
#setting VPC flow logs to capture REJECT traffic only to reduce costs
resource "aws_flow_log" "vpc_rejects" {
  vpc_id          = aws_vpc.vpc.id
  traffic_type    = "REJECT"
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn    = aws_iam_role.vpc_flow_role.arn
}

#IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_role" {
  name = "demo-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

#IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_policy" {
  role = aws_iam_role.vpc_flow_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "*"
    }]
  })
}

#IAM Role and Instance Profile for EC2 CloudWatch Agent
resource "aws_iam_role" "ec2_cw_role" {
  name = "ec2-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

#Attach CloudWatch Agent Policy to IAM Role
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

#IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-cloudwatch-profile"
  role = aws_iam_role.ec2_cw_role.name

}

#SSM Parameter for CloudWatch Agent configuration
resource "aws_ssm_parameter" "cw_agent_config" {
  name = "AmazonCloudWatch-linux"
  type = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/messages"
              log_group_name  = "/aws/ec2/system"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/access.log"
              log_group_name  = "/aws/ec2/nginx/access"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/nginx/error.log"
              log_group_name  = "/aws/ec2/nginx/error"
              log_stream_name = "{instance_id}"
            }
          ]
        }
      }
    }
  })
}