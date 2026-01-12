# DynamoDB Table for View Counter

resource "aws_dynamodb_table" "view_counter" {
  name         = "cloud-resume-view-counter"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing (free tier eligible)
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String
  }

  tags = {
    Name         = "cloud-resume-view-counter"
    cloud-resume = "true"
  }
}

# Initialize the view counter with first record (id: "1", views: 0)
resource "aws_dynamodb_table_item" "initial_counter" {
  table_name = aws_dynamodb_table.view_counter.name
  hash_key   = aws_dynamodb_table.view_counter.hash_key

  item = jsonencode({
    id = {
      S = "1"
    }
    views = {
      N = "0"
    }
  })

  lifecycle {
    ignore_changes = [item] # Don't overwrite the item on subsequent applies
  }
}

# DynamoDB Table for IP-based Rate Limiting

resource "aws_dynamodb_table" "visitor_rate_limits" {
  name         = "cloud-resume-visitor-rate-limits"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing (free tier eligible)
  hash_key     = "ip"

  attribute {
    name = "ip"
    type = "S" # String - stores visitor IP address
  }

  # TTL to automatically delete old rate limit records after 24 hours
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name         = "cloud-resume-visitor-rate-limits"
    cloud-resume = "true"
    Purpose      = "Rate limiting for view counter"
  }
}
