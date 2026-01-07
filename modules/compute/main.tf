#AutoScaling Group and Launch Template

#Launch Template for AutoScaling Group
resource "aws_launch_template" "web_server_lt" {
  name_prefix            = "${var.environment}-web-server-asg-"
  image_id               = data.aws_ami.newest_linux_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile {
    name = var.instance_profile_name
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
  name                      = "${var.environment}-web-server-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = var.target_group_arns
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