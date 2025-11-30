# CloudFront Distribution Configuration

# Origin Access Control (OAC) - Modern replacement for OAI
resource "aws_cloudfront_origin_access_control" "cloud_resume" {
  name                              = "cloud-resume-s3-oac"
  description                       = "Origin Access Control for Cloud Resume S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cloud_resume" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloud Resume Challenge Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Only Europe and North America

  # Origin - S3 Bucket
  origin {
    domain_name              = aws_s3_bucket.cloud_resume.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.cloud_resume.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.cloud_resume.id
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.cloud_resume.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Cache Policy - Managed CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Response Headers Policy - Managed SecurityHeadersPolicy
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  # Geo Restriction - Europe only
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = [
        "AT", # Austria
        "BE", # Belgium
        "BG", # Bulgaria
        "HR", # Croatia
        "CY", # Cyprus
        "CZ", # Czech Republic
        "DK", # Denmark
        "EE", # Estonia
        "FI", # Finland
        "FR", # France
        "DE", # Germany
        "GR", # Greece
        "HU", # Hungary
        "IE", # Ireland
        "IT", # Italy
        "LV", # Latvia
        "LT", # Lithuania
        "LU", # Luxembourg
        "MT", # Malta
        "NL", # Netherlands
        "PL", # Poland
        "PT", # Portugal
        "RO", # Romania
        "SK", # Slovakia
        "SI", # Slovenia
        "ES", # Spain
        "SE", # Sweden
        "GB", # United Kingdom
        "CH", # Switzerland
        "NO", # Norway
        "IS", # Iceland
      ]
    }
  }

  # SSL Certificate
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Custom Error Responses
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  tags = {
    Name         = "cloud-resume-cloudfront"
    cloud-resume = "true"
  }
}

# S3 Bucket Policy to allow CloudFront access
resource "aws_s3_bucket_policy" "cloud_resume" {
  bucket = aws_s3_bucket.cloud_resume.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.cloud_resume.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cloud_resume.arn
          }
        }
      }
    ]
  })
}
