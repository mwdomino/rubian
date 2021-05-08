# IAM role allowing access to SQS
resource "aws_iam_role" "builder_role" {
  name = "builder_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "builder_profile" {
  name = "builder_profile"
  role = aws_iam_role.builder_role.name
}




resource "aws_iam_policy" "builder_policy" {
  name        = "builder_policy"
  path        = "/"
  description = "Allow rubian builders access to SQS and secretsmanager"
  policy      = data.aws_iam_policy_document.builder_doc.json
}

data "aws_iam_policy_document" "builder_doc" {
  statement {
    actions = [
      "sqs:DeleteMessages",
      "sqs:ReceiveMessages",
      "sqs:ListQueues"
    ]
    resources = [
      aws_sqs_queue.rubian_build_queue.arn,
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      aws_secretsmanager_secret_version.dockerhub_creds.arn,
    ]
  }
}

# attaches policies to role
resource "aws_iam_role_policy_attachment" "builder_attach" {
  role       = aws_iam_role.image_checker_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "builder_role_policy" {
  role       = aws_iam_role.builder_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_launch_configuration" "builder" {
    name_prefix = "builder-"
    image_id = "ami-0d5eff06f840b45e9" # Amazon Linux 2
    instance_type = "c5a.large"
    user_data = "${file("aws/ec2/userdata.sh")}"
    iam_instance_profile = aws_iam_instance_profile.builder_profile.name

    root_block_device {
        volume_type = "gp2"
        volume_size = "16"
    }
}

resource "aws_autoscaling_group" "builders" {
    availability_zones = ["us-east-1a"]
    name = "builders"
    max_size = "5"
    min_size = "0"
    health_check_grace_period = 300
    health_check_type = "EC2"
    desired_capacity = 0
    force_delete = true
    launch_configuration = "${aws_launch_configuration.builder.name}"
}

resource "aws_autoscaling_policy" "builders-scale-up" {
    name = "builders-scale-up"
    scaling_adjustment = 5
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.builders.name}"
}

resource "aws_cloudwatch_metric_alarm" "build-queue-high" {
    alarm_name = "rubian-build-queue-high"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "ApproximateNumberOfMessagesVisible"
    namespace = "AWS/SQS"
    period = "60"
    statistic = "Maximum"
    threshold = "5"
    alarm_description = "Start rubian builders when SQS queue has messages"
    alarm_actions = [
        "${aws_autoscaling_policy.builders-scale-up.arn}"
    ]
    dimensions = {
        QueueName = aws_sqs_queue.rubian_build_queue.name
    }
}

# create secrets for dockerhub login
resource "aws_secretsmanager_secret" "dockerhub_creds" {
  name = "rubian/dockerhub_creds_2"
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds" {
  secret_id     = aws_secretsmanager_secret.dockerhub_creds.id
  secret_string = "{\"username\": \"${var.docker_hub_username}\",\"password\": \"${var.docker_hub_password}\"}"
}

# allow ec2 iam to access those secrets
# userdata loads secrets from cli into ENV for EC2
