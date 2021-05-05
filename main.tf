# General
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

# S3 Bucket rubian_base_bucket
resource "aws_s3_bucket" "rubian_base_bucket" {
  bucket = "rubian-base-version"
  acl    = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "rubian_bucket" {
  bucket = "rubian-bucket-mwdomino"
  acl    = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

# SQS
resource "aws_sqs_queue" "rubian_build_queue" {
  name                      = "rubian_build_queue"
  delay_seconds             = 0
  message_retention_seconds = 7200
  receive_wait_time_seconds = 10
  visibility_timeout_seconds = 600
}

# Logging
resource "aws_cloudwatch_log_group" "rubian" {
  name = "rubian"
}

resource "aws_cloudwatch_log_stream" "rubian-build-logs" {
  name           = "rubian-build-logs"
  log_group_name = aws_cloudwatch_log_group.rubian.name
}

# pip install in lambda folder
resource "null_resource" "pip_install" {
  triggers = {
    src_hash = "#{path.module}/lambda/requirements.txt"
  }

  provisioner "local-exec" {
    command = "pip3 install -r ${path.module}/lambda/requirements.txt -t ${path.module}/lambda/"
  }
}

# zip it up
data "archive_file" "lambda_zip" {
  type = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/lambda.zip"
  excludes    = [ "${path.module}/lambda/lambda.zip" ]

  depends_on = [null_resource.pip_install]
}

# upload to s3 - rubian_bucket
resource "aws_s3_bucket_object" "lambda_object" {
  bucket = aws_s3_bucket.rubian_bucket.bucket
  key    = "lambda.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = data.archive_file.lambda_zip.output_md5
}

# create lambda image_checker:
#     lambda.image_checker_handler

# create lambda image_scraper:
#     lambda.image_scraper_handler

# Launch Template
#resource "aws_launch_template" "foo" {
#  name = "foo"
#}
# EC2 ASG
#   min 0, max 100 a1.large
#   scales from SQS queue length > 0
#   instances killed after 45 minutes to prevent charges
