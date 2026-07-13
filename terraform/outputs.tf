output "lambda_function_name" {
  description = "Deployed Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  description = "Deployed Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "codebuild_project" {
  description = "CodeBuild project name."
  value       = aws_codebuild_project.this.name
}

output "artifacts_bucket" {
  description = "S3 bucket holding versioned Lambda zips."
  value       = aws_s3_bucket.artifacts.bucket
}
