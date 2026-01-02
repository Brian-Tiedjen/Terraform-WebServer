Architecture summary (ALB → private EC2 → NAT → IGW)

Terraform Version: 1.14.3 
AWS version: 6.27.0
local version: 2.6.1
random version: 3.5.1

##How to Deploy##

- terraform init
- terraform plan
- terraform apply -auto-approve

##To Destroy##
- terraform destroy -auto-approve

Costs:
ALB: TBD
NAT Gateway: TBD
EC2: TBD
CloudWatch: TBD
S3: TBD


##Notes##

This project is planned to be a fully built out cloud infrastrucuture to demo some of the following components and show my familiarity with them
- VPC
- NAT Gateway (single)
- Subnets
- ALBs
- EC2 instances and configuration (add user data from github)
- IAM and use with EC2 instances
- Security Groups
- Cloud Watch (both logs and alarms)
- Terraform as IAC
- S3 bucket back end with DynomoDB locking

Note:
This is a personal project and not affiliated with my employer in any way. All resources created in this project are for demo purposes only and should not be used in production or sensitive environments.

Issues
~~Subnets not working with ALB - Investigate~~

~~need 2nd instance?~~

~~Using same subnet - why?~~ 

~~Fix variables for subnets~~

~~intenet gateway getting hung on destroy? over 20 min Update: not gateway but the ALB has deletion protection on, when I disable it destroy now works~~
~~Update: Turned off deletion protection~~

~~Can not detlete bucket (not empty and you must delete all versions in the bucket appear as errors) Added a force destroy flag for the s3 bucket~~

Future Update Ideas:
-add more logging
