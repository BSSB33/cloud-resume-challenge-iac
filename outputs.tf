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

output "uploaded_files" {
  description = "List of uploaded website files"
  value       = keys(aws_s3_object.website_files)
}

output "website_files_etags" {
  description = "ETags of uploaded files (for cache invalidation)"
  value = {
    for key, obj in aws_s3_object.website_files : key => obj.etag
  }
}
