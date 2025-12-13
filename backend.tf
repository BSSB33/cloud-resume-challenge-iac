# Terraform S3 Backend Configuration
terraform {
  backend "s3" {
    bucket  = "vitraiaws-terraform-states"
    key     = "cloud-resume-challenge/terraform.tfstate"
    region  = "eu-west-1"
    profile = "vitraigabor"
    encrypt = true
  }
}
