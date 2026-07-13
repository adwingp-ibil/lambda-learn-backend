# Infrastructure (Terraform + CodeBuild)

Terraform provisions the stack — IAM roles, the Lambda function, the CodeBuild
project, and an artifact bucket — using **local state** (no remote backend, no
bootstrap). CodeBuild deploys code by building a zip and running
`aws lambda update-function-code`; Terraform ignores those code changes so the
two never fight.

```
terraform/
  main.tf         provider (local state)
  variables.tf    inputs (all have defaults)
  lambda.tf       IAM role + function (initial code from ../src)
  codebuild.tf    CodeBuild project + a small deploy-only role
  s3.tf           artifact bucket (versioned zip history)
  outputs.tf
```

## Deploy the infrastructure (from your machine)

Needs AWS credentials that can create IAM/Lambda/CodeBuild/S3.

```bash
cd terraform
terraform init
terraform apply          # optionally: cp terraform.tfvars.example terraform.tfvars first
```

This creates the Lambda (`lambda-learn-backend`), its role, the CodeBuild
project (`lambda-learn-backend-build`), and the artifact bucket.

> If a Lambda or role of the same name already exists from an earlier manual
> setup, `terraform apply` will error with "already exists". Import it instead of
> recreating, e.g.:
> `terraform import aws_lambda_function.this lambda-learn-backend`

## Deploy code (CodeBuild)

Push to the repo → CodeBuild runs `buildspec.yml`: `npm install`, zip, then
`aws lambda update-function-code`, and uploads the zip to the artifact bucket.

Builds are triggered manually — start one from the CodeBuild console or with
`aws codebuild start-build --project-name lambda-learn-backend-build`.

You can also deploy code straight from your machine without CodeBuild at all:
`cd src && npm install --omit=dev && zip -r ../lambda.zip . && aws lambda update-function-code --function-name lambda-learn-backend --zip-file fileb://../lambda.zip`

## Notes

- **Local state**: `terraform.tfstate` stays on your machine (gitignored). Back it
  up; don't run `apply` from two places at once.
- Retire any old hand-created CodeBuild project once builds run on
  `lambda-learn-backend-build`, so a push doesn't trigger two builds.
- `*.tfvars` and `.terraform.lock.hcl` are gitignored.
