#provider block and default tags
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Terraform-WebServer"
      terraform   = "true"
    }

  }
}
