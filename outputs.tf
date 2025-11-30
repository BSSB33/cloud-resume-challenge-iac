output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.cloud_resume.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.cloud_resume.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.cloud_resume.region
}
