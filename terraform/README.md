# Terraform deployment (replaces Serverless v3)

This directory deploys the amplify-genai-backend with Terraform. Stage
(`dev`/`staging`/`prod`) is selected by the **Terraform workspace**. The shared
REST API Gateway is **owned externally** (gaiin-platform IaC) and consumed via
its `<stage>-RestApiId` / `<stage>-RestApiRootResourceId` CloudFormation exports.

See `../docs/TERRAFORM_MIGRATION.md` for the full plan and `scripts/import/` for
the state-import workflow.

## Layout

```
versions.tf providers.tf backend.tf variables.tf locals.tf data.tf main.tf outputs.tf
envs/{dev,staging,prod}.tfvars     # mirrors var/<stage>-var.yml (non-SSM values)
modules/                           # reusable building blocks
services/<service>/                # one module per former Serverless service
scripts/import/                    # per-service terraform import scripts
build/                             # layer + package artifacts (gitignored)
```

## One-time backend bootstrap

The S3 state bucket + DynamoDB lock table must exist before `init`. Create them
once (outside this config so `apply` never destroys them), e.g.:

```bash
aws s3api create-bucket --bucket <tf-state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <tf-state-bucket> \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name <tf-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then set the names in `backend.tf` (or pass `-backend-config` at init).

## Usage

```bash
terraform init \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="dynamodb_table=<tf-lock-table>" \
  -backend-config="region=us-east-1"

# pick a stage (workspace) — never deploy from the default workspace
terraform workspace new dev        # first time
terraform workspace select dev

# import existing resources BEFORE the first apply (see scripts/import/README.md)
./scripts/import/import_data-disclosure.sh

terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

## Requirements

- Terraform >= 1.6, AWS provider 5.x
- **Docker** (the Python deps layer builds in the AWS Lambda build image to match
  the runtime, replicating `serverless-python-requirements` dockerizePip).
- AWS credentials with permissions for the resources being managed.

## Validate locally (no AWS calls)

The full local gate is offline — no AWS credentials, no API calls:

```bash
make check        # fmt-check + validate + tflint (recursive)
```

Individual targets: `make fmt`, `make validate`, `make lint`, `make clean`.
Requires `terraform` and `tflint` (install: `brew install terraform-linters/tap/tflint`).

> `terraform plan` / `apply` are deliberately not part of the local gate: `plan`
> reads live data sources (the external `RestApiId` export + shared SSM params) so
> it needs AWS read access, and `apply` changes infrastructure.
