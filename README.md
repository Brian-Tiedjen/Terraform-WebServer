## Architecture summary 

Public ALB → Auto Scaling EC2 (private subnets) → NAT Gateway → Internet Gateway
- This architecture implements a fault-tolerant, scalable web tier using native Amazon Web Services patterns.

## What This Project Demonstrates

This project provisions a production-style AWS network and compute stack using Terraform, including:

This project provisions a production-style AWS network and compute stack using Terraform, with an emphasis on scalability, isolation, and observability.

Key capabilities include:
- Multi-AZ VPC with public and private subnets
- Internet Gateway with single NAT Gateway (cost-aware design)
- Public Application Load Balancer spanning multiple AZs
- Auto Scaling Group of private EC2 web servers behind the ALB
- Launch Template–based instance configuration
- Security group isolation between ALB and EC2 tiers
- Target tracking Auto Scaling policy (CPU @ 70%)
- Rolling instance refresh for safe updates
- IAM instance profile with least-privilege intent
- Remote Terraform state stored in S3 with DynamoDB state locking
- CICD Intergration with GitHub Actions + Enviorment Secrets

Centralized logging:
- ALB access logs
- VPC Flow Logs
- CloudTrail
- CloudWatch Logs

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

Note: ALB deletion protection is disabled to allow clean teardown.


## Costs (Estimated)

Costs are intentionally left as TBD.
This project is designed for short-lived demo deployments and learning purposes, not long-running production workloads.

Primary cost drivers:
- Application Load Balancer
- NAT Gateway
- EC2 instance
- CloudWatch logs and alarms
- S3 storage


## Running Web Server (via ALB)
<img width="501" height="223" alt="image" src="https://github.com/user-attachments/assets/e606c490-2ffa-45e0-aedb-76787abb2257" />

## Logging Bucket
<img width="1378" height="422" alt="image" src="https://github.com/user-attachments/assets/c500d422-c1c4-4ff0-8a1f-584d000845c4" />

## Notes

- This is a personal learning and portfolio project.
- Not affiliated with my employer.
- Resources are created for demonstration purposes only.
- Not intended for production or sensitive workloads.

## Security Considerations

- EC2 instances are deployed exclusively in private subnets
- No inbound internet access to compute resources
- ALB is the only public-facing component
- Security groups enforce ALB → EC2 traffic only
- IAM roles scoped to CloudWatch + SSM only
- VPC Flow Logs capture rejected traffic for analysis

## Failure & Recovery Behavior

- EC2 instance failure triggers automatic replacement via ASG
- ALB health checks remove unhealthy targets
- Multi-AZ design tolerates single AZ failure
- Rolling instance refresh prevents full capacity loss during updates

## CI/CD Workflow

- Pull Requests: terraform init / fmt / validate / plan
- Main Branch Push: approved plan is applied automatically
- Terraform state stored remotely with DynamoDB locking
- Apply needs Approval Via GitHub environment protections

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
- ~~CI-driven Terraform (plan/apply via pipeline)~~
  
## Future Update Ideas

- Modularize infrastructure (VPC, ALB, ASG modules)
- SSM Session Manager working for EC2
- Remote Backend hardening (also getting depreciated commanad error on Dynomo_DB so will need to investigate)
- WAF?
- HTTPS Listener
 
