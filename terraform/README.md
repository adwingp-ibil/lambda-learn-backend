# Infrastructure (Terraform + CodeBuild)

Terraform owns the whole stack — IAM roles, the Lambda function **and its code**,
the CodeBuild project, and an artifact bucket. Remote state lives in S3 with a
DynamoDB lock. CodeBuild deploys by running `terraform apply`, so there's one
source of truth for infra and code.

```
terraform/
  main.tf         provider, S3 backend
  variables.tf    inputs (defaults for most)
  lambda.tf       IAM role + function (code zipped from ../src)
  codebuild.tf    CodeBuild project + its role
  s3.tf           artifact bucket (versioned zip history)
  outputs.tf
  bootstrap/      one-time: creates the state bucket + lock table
```

## First-time setup

**1. Bootstrap the remote-state backend** (once per account/region — uses local state):

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="state_bucket=<globally-unique-name>" -var="aws_region=<region>"
```

**2. Point the main stack at that backend and apply it** (from your machine, with
AWS credentials that can create IAM/Lambda/CodeBuild/S3):

```bash
cd terraform
cp backend.hcl.example backend.hcl        # fill in bucket + region
cp terraform.tfvars.example terraform.tfvars   # set state_bucket
cd ../src && npm install --omit=dev && cd ../terraform   # so the zip has deps
terraform init -backend-config=backend.hcl
terraform apply
```

This creates the Lambda, the CodeBuild project, and everything else.

**3. Connect CodeBuild to GitHub** so pushes trigger builds:
- Add a source credential once (Console → CodeBuild → *GitHub* → connect, or
  `aws codebuild import-source-credentials`).
- Then set `enable_webhook = true` in `terraform.tfvars` and re-run
  `terraform apply`. After that, every push runs `buildspec.yml` → `terraform apply`.

## Day-to-day

Edit code in `src/` (or infra in `terraform/`), commit, and push. CodeBuild
installs deps, runs `terraform apply`, and uploads the deployed zip to the
artifact bucket. To deploy from your machine instead, just run `terraform apply`.

## Notes

- **Config-only knobs** are in `variables.tf`; override in `terraform.tfvars`.
- `backend.hcl`, `*.tfvars`, and `.terraform.lock.hcl` are gitignored (the lock
  file because builds run on Linux and you're on Windows — let each side resolve
  its own provider hashes, or commit it with `terraform providers lock` for both
  platforms).
- The CodeBuild role can manage this stack's resources and its own IAM roles
  (scoped to `lambda-learn-backend-*`). Because it runs `terraform apply`, that
  breadth is expected — keep the role tight to this project.
