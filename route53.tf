# Route53 and DNS Configuration

# Data source to get the existing hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Route53 A Record (IPv4) - Alias to CloudFront
resource "aws_route53_record" "website_ipv4" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloud_resume.domain_name
    zone_id                = aws_cloudfront_distribution.cloud_resume.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA Record (IPv6) - Alias to CloudFront
resource "aws_route53_record" "website_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.cloud_resume.domain_name
    zone_id                = aws_cloudfront_distribution.cloud_resume.hosted_zone_id
    evaluate_target_health = false
  }
}
