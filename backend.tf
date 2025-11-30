# Terraform S3 Backend Configuration
terraform {
  backend "s3" {
    bucket  = "vitraiaws-cloud-resume-terraform-state"
    key     = "cloud-resume-challenge/terraform.tfstate"
    region  = "eu-west-1"
    profile = "vitraigabor"
    encrypt = true
  }
}
