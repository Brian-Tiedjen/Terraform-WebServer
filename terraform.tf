#terraform settings block
terraform {
  required_version = ">= 1.14.3"

  backend "s3" {
    bucket         = "backup-bucket-for-terraform"
    key            = "demo/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"

    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
  }
}

#provider block and default tags
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "demo"
      Project     = "Terraform-AWS-VPC"
      terraform   = "true"
    }

  }
}