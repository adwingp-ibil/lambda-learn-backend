# --- CodeBuild service role ---
# CodeBuild runs `terraform apply`, so its role must be able to manage every
# resource in this stack plus read/write the remote state and lock table.
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "BuildLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }

  # Terraform remote state (S3) + state lock (DynamoDB).
  statement {
    sid       = "TfState"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}", "arn:aws:s3:::${var.state_bucket}/*"]
  }
  statement {
    sid       = "TfLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table}"]
  }

  # Manage the resources Terraform owns. IAM is scoped to this project's role
  # names so a build can't touch unrelated roles.
  statement {
    sid = "ManageStack"
    actions = [
      "lambda:*",
      "logs:*",
      "s3:*",
      "codebuild:*",
    ]
    resources = ["*"]
  }
  statement {
    sid = "ManageIamRoles"
    actions = [
      "iam:GetRole", "iam:PassRole", "iam:CreateRole", "iam:DeleteRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy",
      "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:TagRole", "iam:UntagRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.project_name}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# --- CodeBuild project ---
resource "aws_codebuild_project" "this" {
  name         = "${var.project_name}-build"
  description  = "Builds and deploys ${var.project_name} via terraform apply."
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = var.state_bucket
    }
    environment_variable {
      name  = "TF_STATE_LOCK_TABLE"
      value = var.state_lock_table
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type            = var.source_type
    location        = var.source_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.project_name}"
    }
  }
}

# Optional: trigger a build on every push. Requires a CodeBuild source
# credential (GitHub OAuth/PAT) to already exist in the account/region.
resource "aws_codebuild_webhook" "this" {
  count        = var.enable_webhook ? 1 : 0
  project_name = aws_codebuild_project.this.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
}
