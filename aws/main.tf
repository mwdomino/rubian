terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

variable "docker_hub_username" {
  type = string
  description = "Username to push rubian images through"
}

variable "docker_hub_password" {
  type = string
  description = "Docker Hub password"
}

# S3 Bucket rubian_base_bucket
resource "aws_s3_bucket" "rubian_base_bucket" {
  bucket = "rubian-base-version"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    App         = "Rubian"
  }
}

# Lambda base_image_checker writes to S3 bucket
#   IAM role with access to bucket (GetItem & PutItem)
data "archive_file" "base_image_checker_payload" {
  type          = "zip"
  output_path   = "/tmp/base_image_checker_payload.zip"
  source_dir = "lambda/base_image_checker/"
}

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

resource "aws_iam_role" "image_checker_role" {
  name = "image_checker_role"
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

resource "aws_iam_role_policy_attachment" "lambda_logs_checker" {
  role       = aws_iam_role.image_checker_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "image_checker_function" {
  filename      = data.archive_file.base_image_checker_payload.output_path
  function_name = "image_checker_function"
  role          = aws_iam_role.image_checker_role.arn
  handler       = "base_image_checker.handler"
  source_code_hash = data.archive_file.base_image_checker_payload.output_base64sha256
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

resource "aws_lambda_permission" "allow_cloudwatch_to_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_checker_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_event_rule.arn
}

resource "aws_cloudwatch_event_target" "image_checker_target" {
  arn   = aws_lambda_function.image_checker_function.arn
  rule  = aws_cloudwatch_event_rule.hourly_event_rule.name
  target_id = aws_lambda_function.image_checker_function.function_name
}

# Lambda RubyImageScraper
#   scrapes ruby-lang.org for releases
#   for each release, adds message to SQS queue rubian-build-queue
data "archive_file" "image_scraper_payload" {
  type          = "zip"
  output_path   = "/tmp/image_scraper_payload.zip"
  source_dir = "lambda/image_scraper/"
}

resource "aws_iam_role_policy" "image_scraper_policy" {
  name     = "image_scraper_policy"
  role     = aws_iam_role.image_scraper_role.id
  policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = ["s3:GetObject"]
        Effect    = "Allow"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.rubian_base_bucket.bucket}/version"
      },
      {
        Action    = ["sqs:SendMessage"]
        Effect    = "Allow"
        Resource  = aws_sqs_queue.rubian_build_queue.arn
      }
    ]
  })
}

resource "aws_iam_role" "image_scraper_role" {
  name = "image_scraper_role"
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

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_scraper_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.rubian_base_bucket.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_scraper" {
  role       = aws_iam_role.image_scraper_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "image_scraper_function" {
  filename      = data.archive_file.image_scraper_payload.output_path
  function_name = "image_scraper_function"
  role          = aws_iam_role.image_scraper_role.arn
  handler       = "image_scraper.handler"
  source_code_hash = data.archive_file.image_scraper_payload.output_base64sha256
  runtime = "python3.8"
  timeout = 30

  environment {
    variables = {
      RUBIAN_BUILD_QUEUE  = aws_sqs_queue.rubian_build_queue.id
    }
  }
}
# S3 Event on s3:ObjectPut
#   fires on new version, calls Lambda RubyImageScraper
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.rubian_base_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_scraper_function.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_sqs_queue" "rubian_build_queue" {
  name                      = "rubian_build_queue"
  delay_seconds             = 0
  message_retention_seconds = 7200
  receive_wait_time_seconds = 10
  visibility_timeout_seconds = 1500
}

# EC2 ASG
#   min 0, max 100 a1.large
#   scales from SQS queue length > 0
#   instances killed after 45 minutes to prevent charges
