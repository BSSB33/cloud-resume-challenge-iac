# ACM Certificate Configuration
# Note: ACM certificates for CloudFront MUST be in us-east-1 region

# ACM Certificate in us-east-1
resource "aws_acm_certificate" "cloud_resume" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name         = "cloud-resume-certificate"
    cloud-resume = "true"
  }
}

# DNS validation records for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloud_resume.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "cloud_resume" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloud_resume.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
