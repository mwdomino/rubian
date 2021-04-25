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
