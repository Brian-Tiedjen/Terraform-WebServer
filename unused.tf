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

/*
#Attach EC2 instance to ALB target group
resource "aws_lb_target_group_attachment" "web_instance" {
  target_group_arn = aws_lb_target_group.${var.environment}_alb_group.arn
  target_id        = aws_instance.web_server_private.id
  port             = 80
}
*/

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