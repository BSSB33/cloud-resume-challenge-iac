variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "vitraigabor.eu"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (empty for default credential chain)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudFront monitoring alerts"
  type        = string
  sensitive   = true
}
