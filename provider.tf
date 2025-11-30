terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "vitraigabor"

  default_tags {
    tags = {
      Project     = "cloud-resume-challenge"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
