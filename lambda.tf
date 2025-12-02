# Lambda Function for View Counter

# IAM Role for Lambda
resource "aws_iam_role" "lambda_view_counter" {
  name = "cloud-resume-lambda-view-counter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "cloud-resume-lambda-role"
    cloud-resume = "true"
  }
}

# IAM Policy for DynamoDB access
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_view_counter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.view_counter.arn
      }
    ]
  })
}

# Attach AWS managed policy for Lambda basic execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_view_counter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = file("${path.module}/lambda/view_counter.py")
    filename = "lambda_function.py"
  }
}

# Lambda Function
resource "aws_lambda_function" "view_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cloud-resume-view-counter"
  role             = aws_iam_role.lambda_view_counter.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.view_counter.name
      ALLOWED_ORIGIN = "https://${var.domain_name}"
    }
  }

  tags = {
    Name         = "cloud-resume-view-counter"
    cloud-resume = "true"
  }
}

# Lambda Function URL with CORS configuration
resource "aws_lambda_function_url" "view_counter" {
  function_name      = aws_lambda_function.view_counter.function_name
  authorization_type = "NONE" # Public URL, but protected by CORS

  cors {
    allow_origins     = ["https://${var.domain_name}"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["*"]
    expose_headers    = ["content-type"]
    max_age           = 86400
    allow_credentials = false
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_view_counter" {
  name              = "/aws/lambda/${aws_lambda_function.view_counter.function_name}"
  retention_in_days = 7

  tags = {
    Name         = "cloud-resume-lambda-logs"
    cloud-resume = "true"
  }
}
