terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote state in S3 with a DynamoDB lock table.
  # Values are supplied at init time so this file stays reusable:
  #   local: terraform init -backend-config=backend.hcl
  #   CI:    terraform init -backend-config="bucket=..." -backend-config="dynamodb_table=..." ...
  backend "s3" {
    key = "lambda-learn/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
