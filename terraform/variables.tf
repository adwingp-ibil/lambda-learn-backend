variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name for the Lambda function, IAM roles, and CodeBuild project."
  type        = string
  default     = "lambda-learn-backend"
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_handler" {
  description = "Lambda handler entrypoint (file.export)."
  type        = string
  default     = "index.handler"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "lambda_memory" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "source_repo_url" {
  description = "HTTPS URL of the Git repo CodeBuild builds from."
  type        = string
  default     = "https://github.com/adwingp-ibil/lambda-learn-backend"
}

variable "source_type" {
  description = "CodeBuild source provider: GITHUB, GITHUB_ENTERPRISE, BITBUCKET, or CODECOMMIT."
  type        = string
  default     = "GITHUB"
}

variable "enable_webhook" {
  description = "Create a CodeBuild webhook so pushes to the repo trigger a build. Requires a CodeBuild source credential to already exist in the account."
  type        = bool
  default     = false
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform remote state (must match TF_STATE_BUCKET in buildspec.yml). CodeBuild's role is granted access to it."
  type        = string
  default     = "lambda-learn-tfstate-adwingp"
}
