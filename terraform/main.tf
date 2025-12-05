terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# --------------------------
# Load GitHub Token Secret
# --------------------------
data "aws_secretsmanager_secret" "github_token" {
  name = "dr-github-token"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

# --------------------------
# Lambda IAM Role
# --------------------------
resource "aws_iam_role" "lambda_role" {
  name = "trigger-mlops-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------
# Lambda Function
# --------------------------
resource "aws_lambda_function" "trigger_mlops" {
  function_name = "trigger-mlops-pipeline"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30

  filename = "lambda.zip"

  environment {
    variables = {
      GITHUB_REPO       = "MLOPS-POC"
      GITHUB_REPO_OWNER = "krishu097"
      GITHUB_TOKEN      = data.aws_secretsmanager_secret_version.github_token.secret_string
    }
  }
}

# --------------------------
# S3 Bucket Notification -> Lambda
# --------------------------
resource "aws_s3_bucket_notification" "s3_events" {
  bucket = var.training_data_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_mlops.arn
    events              = ["s3:ObjectCreated:*"]

    filter_suffix = ".csv"
    filter_prefix = "training-data/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_mlops.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.training_data_bucket}"
}
