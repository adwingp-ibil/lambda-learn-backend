# One-time bootstrap: creates the S3 bucket and DynamoDB table that hold the
# main stack's remote state. This module uses LOCAL state (chicken-and-egg: the
# state backend can't manage itself), so keep its terraform.tfstate around.
#
#   cd terraform/bootstrap
#   terraform init
#   terraform apply -var="state_bucket=<globally-unique-name>" -var="aws_region=<region>"

terraform {
  required_version = ">= 1.5"
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

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "Globally-unique name for the Terraform state bucket."
  type        = string
}

variable "state_lock_table" {
  type    = string
  default = "terraform-locks"
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = var.state_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "state_lock_table" {
  value = aws_dynamodb_table.lock.name
}
