# SNS Topic for CloudFront API call alerts

resource "aws_sns_topic" "cloudfront_alerts" {
  name         = "cloud-resume-cloudfront-alerts"
  display_name = "CloudFront API Call Alerts"

  tags = {
    cloud-resume = "true"
  }
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "cloudfront_alerts_email" {
  topic_arn = aws_sns_topic.cloudfront_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic Policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "cloudfront_alerts_policy" {
  arn = aws_sns_topic.cloudfront_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudfront_alerts.arn
      }
    ]
  })
}

# EventBridge Rule to detect CloudFront API calls
resource "aws_cloudwatch_event_rule" "cloudfront_api_calls" {
  name        = "cloud-resume-cloudfront-api-monitoring"
  description = "Detect CloudFront API calls (create, update, delete operations)"

  event_pattern = jsonencode({
    source      = ["aws.cloudfront"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["cloudfront.amazonaws.com"]
      eventName = [
        "CreateDistribution",
        "UpdateDistribution",
        "DeleteDistribution",
        "CreateOriginAccessControl",
        "UpdateOriginAccessControl",
        "DeleteOriginAccessControl"
      ]
    }
  })

  tags = {
    cloud-resume = "true"
  }
}

# EventBridge Target - Send to SNS
resource "aws_cloudwatch_event_target" "cloudfront_to_sns" {
  rule      = aws_cloudwatch_event_rule.cloudfront_api_calls.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.cloudfront_alerts.arn

  input_transformer {
    input_paths = {
      time      = "$.time"
      eventName = "$.detail.eventName"
      user      = "$.detail.userIdentity.principalId"
      sourceIP  = "$.detail.sourceIPAddress"
      region    = "$.detail.awsRegion"
    }

    input_template = <<EOF
"CloudFront API Call Detected"

Event: <eventName>
Time: <time>
User: <user>
Source IP: <sourceIP>
Region: <region>

This is an automated alert from your Cloud Resume Challenge infrastructure monitoring.
EOF
  }
}
