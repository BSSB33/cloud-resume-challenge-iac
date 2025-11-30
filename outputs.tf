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

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.cloud_resume.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.cloud_resume.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cloud_resume.domain_name
}

output "website_url" {
  description = "Website URL (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.cloud_resume.domain_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL"
  value       = "https://${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.cloud_resume.arn
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = data.aws_route53_zone.main.name_servers
}
