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

  versioning {
    enabled = true
  }

  tags = {
    App         = "Rubian"
  }
}

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

# Launch Template
#resource "aws_launch_template" "foo" {
#  name = "foo"
#}
# EC2 ASG
#   min 0, max 100 a1.large
#   scales from SQS queue length > 0
#   instances killed after 45 minutes to prevent charges
