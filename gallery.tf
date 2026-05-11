# Gallery Infrastructure (gallery.vitraigabor.eu)

data "aws_s3_bucket" "gallery_thumbnails" {
  bucket = "vitraiaws-photos-backup-thumbnails"
}

resource "aws_cloudfront_function" "gallery_auth" {
  name    = "gallery-basic-auth"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/cloudfront-functions/gallery-basic-auth.js", {
    auth_credentials = var.gallery_auth_credentials
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_origin_access_control" "gallery" {
  name                              = "gallery-s3-oac"
  description                       = "Origin Access Control for Gallery thumbnails bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "gallery" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Gallery Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = ["gallery.${var.domain_name}"]

  origin {
    domain_name              = data.aws_s3_bucket.gallery_thumbnails.bucket_regional_domain_name
    origin_id                = "S3-${data.aws_s3_bucket.gallery_thumbnails.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.gallery.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${data.aws_s3_bucket.gallery_thumbnails.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.gallery_auth.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = ["HU", "IT"]
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
    Name    = "gallery-cloudfront"
    gallery = "true"
  }
}

resource "aws_s3_bucket_policy" "gallery_thumbnails" {
  bucket = data.aws_s3_bucket.gallery_thumbnails.id

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
        Resource = "${data.aws_s3_bucket.gallery_thumbnails.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.gallery.arn
          }
        }
      }
    ]
  })
}

resource "aws_route53_record" "gallery_ipv4" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "gallery.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.gallery.domain_name
    zone_id                = aws_cloudfront_distribution.gallery.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "gallery_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "gallery.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.gallery.domain_name
    zone_id                = aws_cloudfront_distribution.gallery.hosted_zone_id
    evaluate_target_health = false
  }
}
