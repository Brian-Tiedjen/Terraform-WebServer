#Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "newest_linux_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

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

#Create EC2 instance in private subnet
resource "aws_instance" "web_server_private" {
  ami                    = data.aws_ami.newest_linux_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnets["private_subnet_1"].id
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
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

#Create S3 bucket for backups with versioning enabled and private ACL
resource "aws_s3_bucket" "backups_bucket" {
  bucket = "demo-backups-bucket-${random_string.random_string_ec2.result}"
  tags = {
    Name = "demo_backups_bucket"
  }
  force_destroy = true

}
resource "aws_s3_bucket_versioning" "backups_bucket_versioning" {
  bucket = aws_s3_bucket.backups_bucket.id

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

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.backups_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


data "aws_elb_service_account" "this" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.backups_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.this.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.backups_bucket.arn}/alb/*"
      }
    ]
  })
}

#ALB Resources - Kept seprate for debugging
resource "aws_lb" "alb_public" {
  name               = "demo-alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public_group.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]
  depends_on         = [aws_security_group.alb_public_group]


  access_logs {
    bucket  = aws_s3_bucket.backups_bucket.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = {
    name = "demo-alb-public"
  }
}

resource "aws_lb_target_group" "demo_alb_group" {
  name        = "demo-alb-target-group"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "demo-alb-target-group"
  }

}

resource "aws_lb_target_group_attachment" "web_instance" {
  target_group_arn = aws_lb_target_group.demo_alb_group.arn
  target_id        = aws_instance.web_server_private.id
  port             = 80
}


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

#alarms

#EC2 Instance Alarms

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


