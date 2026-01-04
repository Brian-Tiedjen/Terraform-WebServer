## Architecture summary 

(ALB → private EC2 → NAT → IGW)

## What This Project Demonstrates
This project provisions a production-style AWS network and compute stack using Terraform, including:

- Multi-AZ VPC with public and private subnets
- Internet Gateway + single NAT Gateway design
- Public Application Load Balancer
- Private EC2 web server behind ALB
- Security group isolation between tiers
- CloudWatch alarms and VPC Flow Logs
- S3-backed Terraform state with DynamoDB locking


## Module Versions

- Terraform Version: 1.14.3 
- AWS version: 6.27.0
- local version: 2.6.1
- random version: 3.5.1

## How to Deploy

- terraform init
- terraform plan
- terraform apply -auto-approve

## To Destroy

- terraform destroy -auto-approve

## Costs (Estimated)

Costs are intentionally left as TBD.
This project is designed for short-lived demo deployments and learning purposes, not long-running production workloads.

Primary cost drivers:
- Application Load Balancer
- NAT Gateway
- EC2 instance
- CloudWatch logs and alarms
- S3 storage


## Screen Shot of running server
<img width="488" height="270" alt="image" src="https://github.com/user-attachments/assets/590e6c9b-841d-4621-bf89-60eb7d8d4267" />


## Screen shot of logs buckets
<img width="1378" height="422" alt="image" src="https://github.com/user-attachments/assets/c500d422-c1c4-4ff0-8a1f-584d000845c4" />

## Notes

This is a personal project and not affiliated with my employer in any way. All resources created in this project are for demo purposes only and should not be used in production or sensitive environments.

## Issues
- ~~Subnets not working with ALB - Investigate~~
- ~~need 2nd instance?~~
- ~~Using same subnet - why?~~ 
- ~~Fix variables for subnets~~
- ~~internet gateway getting hung on destroy? Over 20 min Update: not gateway but the ALB has deletion protection on, when I disable it, it no longer works~~
- ~~Update: Turned off deletion protection~~
- ~~Can not delete bucket (not empty and you must delete all versions in the bucket appear as errors) Added a force destroy flag for the S3 bucket~~
- ~~Add a diagram~~
- ~~Add more logging~~
- ~~Auto Scaling Group~~
  
## Future Update Ideas
