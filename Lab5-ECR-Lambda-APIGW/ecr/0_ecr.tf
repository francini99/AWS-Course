terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

# Creating Elastic Container Repository for application
resource "aws_ecr_repository" "flask_app_serverless" {
  name = "flask-app-serverless"
}