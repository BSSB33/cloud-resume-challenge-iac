# S3 Bucket for Cloud Resume Challenge
resource "aws_s3_bucket" "cloud_resume" {
  bucket = "vitraiaws-cloud-resume-challenge"

  tags = {
    Name         = "cloud-resume-challenge"
    cloud-resume = "true"
  }
}
