# --- CodeBuild service role ---
# CodeBuild runs `terraform apply`, so its role must manage every resource in
# this stack plus read/write the S3 remote state (locking is an S3 object via
# use_lockfile, so no DynamoDB permissions are needed).
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

  # Terraform remote state + S3-native lock object.
  statement {
    sid       = "TfState"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}", "arn:aws:s3:::${var.state_bucket}/*"]
  }

  # Pull source from GitHub via the CodeConnections connection. Without this the
  # DOWNLOAD_SOURCE phase fails with "Access denied to connection".
  statement {
    sid = "UseCodeConnection"
    actions = [
      "codeconnections:UseConnection",
      "codeconnections:GetConnection",
      "codeconnections:GetConnectionToken",
      "codestar-connections:UseConnection",
      "codestar-connections:GetConnection",
      "codestar-connections:GetConnectionToken",
    ]
    resources = [var.codeconnection_arn]
  }

  # Manage the resources Terraform owns.
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

  # IAM scoped to this project's own roles so a build can't touch unrelated ones.
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
    # TF_STATE_BUCKET / TF_STATE_KEY / TERRAFORM_VERSION come from buildspec.yml;
    # AWS_DEFAULT_REGION is provided automatically by CodeBuild.
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
