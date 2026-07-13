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

  # Local state (terraform.tfstate on disk). Simple, no bootstrap needed.
  # State lives only on the machine that runs apply — keep it, and don't run
  # apply from two places at once.
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
