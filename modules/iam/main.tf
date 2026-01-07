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
