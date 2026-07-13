terraform {
  # >= 1.10 for S3-native state locking (use_lockfile) — no DynamoDB table.
  required_version = ">= 1.10"

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

  # Remote state in S3. Config is supplied at init time so this file stays
  # reusable:
  #   local: terraform init -backend-config="bucket=..." -backend-config="key=..." \
  #                         -backend-config="region=..." -backend-config="use_lockfile=true"
  #   CI:    buildspec.yml passes the same flags.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
