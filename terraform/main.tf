terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------
# GitHub Token from Secrets Manager
# -----------------------------
data "aws_secretsmanager_secret" "github_token" {
  name = "dr-github-token"
}

data "aws_secretsmanager_secret_version" "github_token_value" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

# -----------------------------
# Existing S3 Bucket
# -----------------------------
data "aws_s3_bucket" "training_data" {
  bucket = var.training_data_bucket
}

# -----------------------------
# IAM Role for Lambda
# -----------------------------
resource "aws_iam_role" "lambda_role" {
  name = "mlops-trigger-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_mlops_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# Lambda Function Package
# -----------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_function.py"
  output_path = "${path.module}/lambda.zip"
}

# -----------------------------
# Lambda Function
# -----------------------------
resource "aws_lambda_function" "trigger_mlops" {
  function_name = "trigger-mlops-pipeline"
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  timeout       = 30
  role          = aws_iam_role.lambda_role.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      GITHUB_TOKEN      = data.aws_secretsmanager_secret_version.github_token_value.secret_string
      GITHUB_REPO_OWNER = var.github_repo_owner
      GITHUB_REPO       = var.github_repo
    }
  }
}

# -----------------------------
# Allow S3 to Invoke Lambda
# -----------------------------
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_mlops.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.training_data.arn
}

# -----------------------------
# S3 Event Notification Trigger
# -----------------------------
resource "aws_s3_bucket_notification" "trigger" {
  bucket = data.aws_s3_bucket.training_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_mlops.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.training_data_prefix
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}