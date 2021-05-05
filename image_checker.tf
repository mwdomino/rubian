# Lambda base_image_checker writes to S3 bucket
#   IAM role with access to bucket (GetItem & PutItem)

# Allows access to s3/version
resource "aws_iam_role_policy" "image_checker_policy" {
  name     = "image_checker_policy"
  role     = aws_iam_role.image_checker_role.id
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = ["s3:PutObject", "s3:GetObject"]
        Effect    = "Allow"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.rubian_base_bucket.bucket}/version"
      }
    ]
  })
}

# allows lambda to assume role
resource "aws_iam_role" "image_checker_role" {
  name = "image_checker_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# allows access to send logs
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# attaches policies to role
resource "aws_iam_role_policy_attachment" "lambda_logs_checker" {
  role       = aws_iam_role.image_checker_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# lambda function
resource "aws_lambda_function" "image_checker_function" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "rubian-image_checker"
  role          = aws_iam_role.image_checker_role.arn
  handler       = "lambda.base_image_checker_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime = "python3.8"
  timeout = 15

  environment {
    variables = {
      DOCKER_HUB_USERNAME = var.docker_hub_username
      DOCKER_HUB_PASSWORD = var.docker_hub_password
      RUBIAN_BASE_BUCKET  = aws_s3_bucket.rubian_base_bucket.bucket
    }
  }

  # If this function is deployed first we may miss the first S3 event
  depends_on = [
    aws_lambda_function.image_scraper_function
  ]
}

# Run image_checker_function hourly
resource "aws_iam_role" "hourly_event_role" {
  name = "hourly_event_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "hourly_event_rule" {
  name        = "image_checker_hourly"
  description = "Run image checker every hour"
  schedule_expression = "rate(1 hour)"
  role_arn = aws_iam_role.hourly_event_role.arn
}

# allow cloudwatch to trigger lambda
resource "aws_lambda_permission" "allow_cloudwatch_to_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_checker_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_event_rule.arn
}

# cloudwatch target
resource "aws_cloudwatch_event_target" "image_checker_target" {
  arn   = aws_lambda_function.image_checker_function.arn
  rule  = aws_cloudwatch_event_rule.hourly_event_rule.name
  target_id = aws_lambda_function.image_checker_function.function_name
}
