# IK Website Infrastructure (ik.vitraigabor.eu)

resource "aws_s3_bucket" "ik_website" {
  bucket = "vitraiaws-ik-website"

  tags = {
    Name       = "ik-website"
    ik-website = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "ik_website" {
  bucket = aws_s3_bucket.ik_website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "ik_website" {
  name                              = "ik-website-s3-oac"
  description                       = "Origin Access Control for IK Website S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "ik_website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "IK Website Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = ["ik.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.ik_website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.ik_website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.ik_website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.ik_website.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE", "GB", "CH", "NO", "IS",
      ]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloud_resume.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

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
    Name       = "ik-website-cloudfront"
    ik-website = "true"
  }
}

resource "aws_s3_bucket_policy" "ik_website" {
  bucket = aws_s3_bucket.ik_website.id

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
        Resource = "${aws_s3_bucket.ik_website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.ik_website.arn
          }
        }
      }
    ]
  })
}
