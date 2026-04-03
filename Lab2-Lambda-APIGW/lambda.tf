terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

# =========================
# IAM ROLE FOR LAMBDA
# =========================
resource "aws_iam_role" "lambda_role" {
  name = "aws_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# =========================
# IAM POLICY
# =========================
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"

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

# =========================
# ATTACH POLICY TO ROLE
# =========================
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# =========================
# ZIP YOUR LAMBDA
# =========================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "main.py"
  output_path = "${path.module}/main.zip"
}

# =========================
# S3 BUCKET (STORE ZIP)
# =========================
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "francini-lambda-bucket-12345"
}

# =========================
# UPLOAD ZIP TO S3
# =========================
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "main.zip"
  source = data.archive_file.lambda_zip.output_path
}

# =========================
# LAMBDA FUNCTION
# =========================
resource "aws_lambda_function" "lambda_function" {
  function_name = "Lambda-Function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.8"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_zip.key

  depends_on = [
    aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role
  ]
}

# =========================
# API GATEWAY PERMISSION
# =========================
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
}