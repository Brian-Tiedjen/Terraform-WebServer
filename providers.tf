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