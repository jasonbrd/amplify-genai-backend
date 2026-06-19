# Serverless v3 → Terraform Migration Plan

> Status: **in progress** (branch `terraform`)
>
> This is a living document. Update the progress checkboxes as phases complete.

## Goal

Migrate the entire `amplify-genai-backend` monorepo from Serverless Framework v3
(+ `serverless-compose` + 7 plugins) to Terraform, and remove all Serverless v3
dependencies, **without recreating live stateful resources** (DynamoDB tables,
S3 buckets, SQS queues) or causing API downtime.

## Confirmed decisions

1. **Shared REST API Gateway is owned by `amplify-lambda` (CORRECTED).** Initial
   planning assumed the API was externally owned. It is **not** — `amplify-lambda`
   auto-creates `ApiGatewayRestApi` from its `http` events and exports it as
   `${stage}-RestApiId` / `${stage}-RestApiRootResourceId` (confirmed by reading
   its `Outputs`; export names are account/region-unique). **Decision (Option 1):**
   Terraform takes ownership — the `amplify-lambda` module creates
   `aws_api_gateway_rest_api` (the existing API, e.g. `dkx9108zuc`, is imported),
   and every other service module consumes the id/root id from
   `module.amplify_lambda` outputs (no CloudFormation-export data source).
   The external `gaiin-platform` IaC owns VPC/Cognito/RDS/secrets/Route53/pandoc —
   but **not** the API.
2. **Terraform workspaces** drive the `dev` / `staging` / `prod` split. One state
   per workspace in the S3 backend.
3. **State import, not recreate.** Every existing resource is brought into
   Terraform state with `terraform import` and verified with an empty `plan` diff
   before any `apply`.

## Current-state architecture (what Serverless does today)

- **16 services**, orchestrated by `serverless-compose.yml`. 15 are Python
  (`python3.11`); `amplify-lambda-js` is Node (`nodejs22.x`, x86_64, X-Ray on).
  `amplify-lambda-python-base` is a non-deployed template (`service: example-service`).
- **Shared REST API Gateway** owned externally. 15 services attach `http` routes
  by importing `${stage}-RestApiId` + `${stage}-RestApiRootResourceId`.
  `amplify-lambda` additionally references a locally-created `ApiGatewayRestApi`
  for its API-timeout custom resource — **verify during Phase 0 import** that this
  resolves to the same shared API and is not a second API.
- **Cross-service linking via SSM Parameter Store** (v0.9.0 change). Each service
  publishes its own resource names to `/amplify/${stage}/<service-name>/<KEY>` and
  consumes others' values via `${ssm:/amplify/${stage}/amplify-<dep>-<svc>/<KEY>}`.
  Shared config (Cognito, domain, OAuth, secrets ARNs) lives at
  `/amplify/${stage}/<KEY>`.
- **Lambda-backed CloudFormation custom resources** (to be retired):
  - `ParameterStoreAutoPopulate` (`utilities/parameter_store_populator`) — writes
    a service's env vars into SSM on every deploy.
  - `ApiGatewayTimeoutConfig` (`utilities/runtime_config_manager`) — PATCHes API
    Gateway integration timeouts above the default after deploy. `amplify-lambda`
    owns the manager Lambda and exports `${stage}-RuntimeConfigManagerArn`; other
    services invoke it.
- **Four layer mechanisms**:
  - `serverless-python-requirements` (`dockerizePip: true`, `layer: true`) — per
    service Python deps layer (`PythonRequirementsLambdaLayer`).
  - Local `markitdown` layer (path-based) in `amplify-lambda`.
  - Externally built `litellm` layer via `build-layer.sh` + `scripts/`.
  - External `PANDOC` layer ARN pulled from SSM (`PANDOC_LAMBDA_LAYER_ARN`).
- **Per-resource IAM managed policies** (`-ssm`, `-s3`, `-dynamodb`, `-sqs`,
  `-secrets`, `-rds`, `-apigateway`) attached to a shared per-service execution
  role; plus `serverless-iam-roles-per-function` where per-function roles are used.
- **Events**: REST API `http`, `sqs`, `schedule` (EventBridge cron), `s3` →
  Lambda (`AWS::Lambda::Permission`), and Lambda **Function URLs** with
  `RESPONSE_STREAM` (Node `chat`/`chat_stream`).
- **External IaC inputs** (from `var/<stage>-var.yml` + SSM): VPC, subnets,
  Cognito, RDS/Aurora, Secrets Manager, Route53 zone, Pandoc layer ARN.

## Plugin → Terraform mapping

| Serverless v3 plugin | Purpose | Terraform replacement |
|---|---|---|
| `serverless-python-requirements` | Dockerized Python deps layer | `null_resource` (docker pip build) + `archive_file` + `aws_lambda_layer_version` (module `python-deps-layer`) |
| `serverless-domain-manager` | Custom domain + Route53 + ACM | `aws_api_gateway_domain_name` + `aws_api_gateway_base_path_mapping` + `aws_route53_record` |
| `serverless-iam-roles-per-function` | Per-function IAM roles | `aws_iam_role` per function in `python-lambda`/`node-lambda` modules |
| `serverless-prune-plugin` | Delete old versions | Not needed — Terraform manages versions in state |
| `serverless-cloudformation-changesets-v3` | Review before deploy | `terraform plan` (native) |
| `serverless-offline` | Local API emulation | Out of deploy scope; keep `localServer.js`, document LocalStack/SAM for Python |
| `serverless-deployment-bucket` | Artifact bucket | `aws_s3_bucket` for TF artifacts + S3 backend |
| `@serverless/compose` | Multi-service orchestration | Terraform modules + workspace; explicit `depends_on` for ordering |

## Serverless custom resources → native Terraform

| Custom resource | Replacement |
|---|---|
| `ParameterStoreAutoPopulate` | Native `aws_ssm_parameter` per published key (`ssm-publish` module). Removes a runtime/circular dependency. |
| `ApiGatewayTimeoutConfig` | Set `aws_api_gateway_integration.timeout_milliseconds` directly. Retire `runtime_config_manager` + its export. |

## Target Terraform layout

```
terraform/
  versions.tf            # required_version + provider constraints
  providers.tf           # aws provider, default tags
  backend.tf             # S3 backend (workspace_key_prefix)
  variables.tf           # inputs mirroring var/<stage>-var.yml
  locals.tf              # stage = terraform.workspace, naming, shared SSM lookups
  data.tf                # external API GW export lookup, account/region, shared SSM
  main.tf                # wire service modules
  outputs.tf
  envs/
    dev.tfvars  staging.tfvars  prod.tfvars
  modules/
    python-deps-layer/   # dockerized pip build -> layer
    python-lambda/        # lambda + role + log group + layer wiring
    node-lambda/          # node lambda (+ function URL / streaming)
    rest-api-route/       # API GW resource+method+integration+permission on shared API
    ssm-publish/          # aws_ssm_parameter fan-out (replaces populator)
    api-gateway-timeout/  # integration timeout helper (replaces runtime_config_manager)
  services/
    data-disclosure/      # FIRST reference service (leaf)
    object-access/  amplify-lambda/  amplify-assistants/  ... (remaining)
  scripts/
    import/               # per-service terraform import scripts + import maps
```

Stage is selected by `terraform.workspace` (no `-var stage=`). `var/<stage>-var.yml`
values move into `envs/<stage>.tfvars`.

## Phased execution plan

- [ ] **Phase 0 — Discovery & import map**
  - [x] Confirmed `${stage}-RestApiId`=`dkx9108zuc` / `RootResourceId`=`5jv0zwxw6l` are
        externally owned; `data-disclosure` attaches to that shared API. `DEP_NAME=afai`,
        account `596434363480`. (Still TODO: confirm `amplify-lambda` doesn't create a 2nd API — check its stack in Phase 3.)
  - [x] Exported `data-disclosure-dev` stack resources; built its import map + script.
  - [ ] Export remaining service stacks as each is migrated.
- [x] **Phase 1 — Foundations** (backend, providers, versions, variables, tfvars, workspace wiring)
- [x] **Phase 1 — Reusable modules** (`python-deps-layer`, `python-lambda`, `node-lambda`, `rest-api-route`, `ssm-publish`, `api-gateway-timeout`)
- [x] **Phase 2 — First leaf service** end-to-end (`data-disclosure`) with import script; `plan` must show empty diff.
- [x] **Phase 3 — Foundational + shared pieces** — `amplify-lambda` **scaffolded + validated**: creates the shared `aws_api_gateway_rest_api` (Terraform now owns it; import existing `dkx9108zuc`), 7 IAM managed policies + role, deps + markitdown layers + external pandoc passthrough, 6 SQS queues/DLQs + queue policies, 11 DynamoDB tables, 10 S3 buckets (consolidation w/ versioning/lifecycle/PAB + 3 Lambda notifications; rag-input/rag-chunks → SQS notifications; image-input → Lambda), ~41 functions, 2 EventBridge schedules, S3→Lambda + S3→SQS events. Retired `parameter_store_populator` + `runtime_config_manager`. Root rewired: all services consume `module.amplify_lambda.rest_api_id`.
- [ ] **Phase 4 — Remaining services** in `serverless-compose` dependency order, importing state for each.
  - [x] `object-access` scaffolded + locally validated (22 functions, 5 DynamoDB tables w/ GSIs, Cognito access, extended-timeout routes). Import pending its stack output.
  - [x] Leaf services scaffolded + locally validated: `chat-billing` (2 tables), `amplify-lambda-artifacts` (1 table + retained S3 bucket), `amplify-lambda-ops` (1 table), `amplify-lambda-api` (S3 bucket + VPC notebook-proxy lambdas + security group). Imports pending stack output.
  - [ ] Non-leaf / complex (in progress): `amplify-lambda-admin` **scaffolded + locally validated** (SQS queue + DLQ, SNS topic, 3 DynamoDB tables incl. 2 streamed + GSIs + TTL, SQS & DynamoDB-stream event-source mappings, `rate(3 minutes)` EventBridge schedule, AgentCore gateway role + provisioner Lambda, dual IAM roles).
  - [x] `assistants-api` **scaffolded + validated** (layer-based, ~26 HTTP functions w/ per-function OAUTH env, 4 DynamoDB tables, S3 bucket, KMS-via-SSM policy, 3 extended-timeout routes; publishes `OAUTH_USER_TABLE`).
  - [x] `assistants-api-google` + `assistants-api-office365` **scaffolded + validated** (vendored deps, `{proxy+}` routes, **DynamoDB-stream trigger on admin's table** wired via module reference — the former `${stage}-AmplifyAdminTableStreamArn` CFN import).
  - [x] `amplify-assistants` **scaffolded + validated** (27 HTTP functions, 8 DynamoDB tables w/ many GSIs, 2 S3 buckets, cross-service Lambda-invoke permission to `assistants-api`; its own SSM populator replaced by the native `ssm-publish` module).
  - [x] `embedding` **scaffolded + validated** — consumes amplify-lambda's queue ARNs/URLs via module outputs; owns Aurora PostgreSQL Serverless v2 cluster (+ prod-only 2nd instance), KMS key, generated DB secret (random_password), DB + Lambda security groups, VPC lambdas, 2 SQS event-source mappings, EMBEDDING_PROGRESS table.
  - [x] `amplify-lambda-js` **scaffolded + validated** (Node, `node-lambda` module): billing + group-assistant functions, Function URL `RESPONSE_STREAM` chat handler, the manual `chat_stream` streaming API GW integration, X-Ray, Bedrock policy, 6 owned tables + traces bucket + conversation-analysis queue.
  - [x] `amplify-agent-loop-lambda` **scaffolded + validated** (vendored-deps Python — NOT a container image despite the `deploymentMethod: direct` comment): agent router/queue/scheduler/tools functions, SQS+DLQ, SNS email topic → queue (with SES/SNS policies), 5 owned tables, 4 buckets (raw-emails w/ lifecycle+PAB+SES policy), dual IAM policies.

**All 15 deployable services scaffolded + locally validated.** (`amplify-lambda-python-base` is a non-deployed template — skipped.)

## Packaging: layer vs vendored deps (important correction)

`serverless-python-requirements` behaves two ways depending on `layer: true`:
- **`layer: true`** (object-access, chat-billing): deps go in a Lambda **layer**
  (`PythonRequirementsLambdaLayer`); functions reference it. → use the
  `python-deps-layer` module + `archive_file` (source only) + `layer_arns`.
- **no `layer:`** (data-disclosure, artifacts, ops, api, admin, amplify-lambda):
  deps are **vendored into the function package**. → use the new
  `python-package` module (builds source + `pip install -t` deps into one zip).
  These functions get **no** layer.

An earlier pass incorrectly gave the vendored-deps services a layer; corrected.
Check each service's `layer:` flag before choosing the packaging module.

## Migration gotchas (discovered while building)

- **Serverless default `memorySize` is 1024 MB.** Functions that don't set
  `memorySize` run at 1024, not the Lambda API default of 128. Service modules set
  `memory_size = 1024` for those functions so imports don't show a memory change.
- **Auto-named managed policies.** `object-access`'s `ObjectAccessLambdaPolicy` has
  no `ManagedPolicyName`, so CloudFormation generated a random name. The module uses
  `name_prefix` (not `name`) so `terraform import` keeps the existing generated name
  without forcing a replace.
- **IAM role names embed the region** (`...-<stage>-<region>-lambdaRole`), matching
  Serverless's generated name so imports don't rename/replace the role.
- **CORS OPTIONS already exist** on every `cors:true` path and must be imported
  (method + mock integration + both responses) or `apply` hits `ConflictException`.
- **Per-service stage redeploy.** Each former Serverless stack created its own
  `AWS::ApiGateway::Deployment` against the shared API. The `rest-api-route` module
  replicates this with a CLI-based redeploy keyed off the route hash, avoiding
  ownership conflicts over the external stage during incremental migration.

## Open items from the complex set (amplify-lambda-admin)

- **CloudFormation export → Terraform.** admin exported `${stage}-AmplifyAdminTableStreamArn`
  (consumed by `assistants-api-google`/`office365` for a DynamoDB-stream trigger).
  Replaced with a module **output** (`admin_table_stream_arn`) consumed directly in
  TF, and also published to SSM (`AMPLIFY_ADMIN_TABLE_STREAM_ARN`). The other admin
  exports (`CriticalErrorsQueueArn/Url`, `CriticalErrorsNotificationTopicArn`) have
  **no in-repo consumers**; exposed as outputs. **Decision needed:** if the external
  gaiin-platform IaC or the frontend imports any of these CFN exports, we need a
  compatibility shim (a small `aws_cloudformation_stack` that re-publishes the
  exports) so we don't break cross-stack `Fn::ImportValue` consumers.
- **AgentCore provisioner.** The `provision_agentcore_web_search` Lambda + the
  `agentcore-gateway` IAM role are created, but the Lambda is **not auto-invoked**
  (its handler expects a CloudFormation custom-resource event with a ResponseURL).
  It is opt-in and disabled by default (`web_search_agentcore_enabled = false`), so
  this is a no-op today. To wire deploy-time provisioning later, either add a
  direct-invoke path to the handler or invoke it via an `aws_lambda_invocation`
  with a synthesized event. Flagged, not silently auto-run.

## Cross-service config: module outputs, not SSM reads (Option B)

Cross-service resource **names** (the table/bucket/queue names one service creates
and another consumes) flow through **module outputs**, not `data.aws_ssm_parameter`
reads. Each producer exposes a `published_params` output (the exact map it also
publishes to SSM), and the root `main.tf` wires it into every consumer as a typed
`map(string)` input (e.g. `lambda_params = module.amplify_lambda.published_params`).
Consumers reference values as `var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]`.

Why: the former `data.aws_ssm_parameter` cross-service reads referenced a plain
string path, so Terraform evaluated them at **plan** time with no dependency edge to
the producer. On a brand-new environment those params don't exist yet, so the plan
failed (`ParameterNotFound`) before anything could be created. Sourcing the values
from producer outputs makes them **known at plan time** (they are pure functions of
`name_prefix` + `stage`), so a greenfield environment deploys with a single
`terraform apply` — no `-target` bootstrap, no pre-seeding.

What is still read from SSM (`data.aws_ssm_parameter`): only **shared/external**
config at `/amplify/${stage}/<KEY>` — populated by the external IaC / the legacy
`populate_parameter_store.py` from `var/<stage>-var.yml` (Cognito, domain, OAuth,
VPC/subnets, secrets ARNs, MIN/MAX_ACU, pandoc layer ARN, etc.). These exist in any
target environment by assumption, so they resolve at plan time.

`ssm-publish` is **retained** in every producer: services still write their names to
`/amplify/${stage}/<service-name>/<KEY>` so the Lambda runtime and any external
consumers keep the v0.9.0 Parameter Store contract. Only Terraform-internal wiring
stopped reading them back.

### No dependency cycle

Several services are both producer and consumer and reference each other
(`amplify-lambda ↔ embedding`, `amplify-lambda ↔ chat-billing/admin/object-access/
amplify-js`, `assistants-api → google/office365`, etc.). This is **not** a Terraform
cycle: every `published_params` output is derived solely from `var.name_prefix` +
`var.stage` (e.g. `"${name_prefix}-lambda-${stage}-accounts"`) and never references
another module, so each `published_params` node is a graph **sink**. All
cross-module edges point *into* a sink; none point back out, so no loop can form.
The few resource-attribute outputs that ARE dependency-tracked — the REST API id,
the RAG/embedding queue ARNs, and admin's table stream ARN — come from producers
that do not depend on their consumers, so they don't close a loop either. (Admin's
`AMPLIFY_ADMIN_TABLE_STREAM_ARN` is a resource attribute, so it is kept OUT of the
consumable `published_params` output and published only to SSM, to avoid a
known-after-apply value rippling into consumers' plans.) `make check`
(fmt/validate/tflint) is green; cycles only surface at `plan`, and the sink argument
above guarantees there is none.

### Deploying a brand-new environment (only external IaC resources exist)

With cross-service values sourced from module outputs, a greenfield environment is a
single pass — no import, no `-target` bootstrap:
1. **Backend**: if it's a new AWS account, bootstrap the state bucket + lock table
   (`scripts/bootstrap`). If it reuses the existing backend, the workspace isolates
   state.
2. **Workspace / vars**: `guard.tf` restricts workspaces to `dev|staging|prod`. A new
   *deployment* (new `dep_name`) within an existing stage just needs a new
   `envs/<name>.tfvars` with that `dep_name`; a brand-new *stage* name must be added
   to `valid_stages` in `locals.tf`.
3. **External config present**: the shared `/amplify/${stage}/<KEY>` SSM params
   (Cognito, domain, OAuth, VPC/subnets, secrets ARNs, ACUs, pandoc layer ARN) must
   already be populated by the external IaC / `populate_parameter_store.py`.
4. `terraform workspace select <stage>` → `terraform apply -var-file=envs/<env>.tfvars`.
   Terraform creates everything, including the REST API (created fresh, not imported)
   and the stage/deployment (the route module's `create_deployment` calls
   `aws apigateway create-deployment`, which creates the stage).
5. **Post-apply**: run the `chat_stream` streaming patch (below) and request the API
   Gateway integration-timeout quota increase if any route needs > 29s.

### REST API import (Phase 3)

`amplify-lambda` creates `aws_api_gateway_rest_api.shared`. Import the existing API
so it is not recreated (which would orphan every attached method and break the
custom domain):
```
terraform import 'module.amplify_lambda.aws_api_gateway_rest_api.shared' dkx9108zuc
```
Then review the plan for name/endpoint/policy drift and reconcile before apply.

### Provider gaps requiring out-of-band CLI (post-apply)

- **Node `chat_stream` response streaming.** The AWS provider (v5) can't express
  `Integration.ResponseTransferMode = STREAM`, and caps `timeout_milliseconds` at
  300000 (response streaming wants 900000). After apply, patch once:
  ```
  aws apigateway update-integration --rest-api-id <id> --resource-id <rid> \
    --http-method POST --patch-operations \
      op=replace,path=/responseTransferMode,value=STREAM \
      op=replace,path=/timeoutInMillis,value=900000
  ```
- **Extended API GW integration timeouts > 29s** (chat, embedding-dual-retrieval,
  the assistants/object-access long routes) require an account **service-quota
  increase** on the REST API, the same prerequisite the old runtime_config_manager
  assumed. The module sets `timeout_ms` via `var.api_gateway_max_timeout_ms`.
- [x] **Phase 5 — Custom domain** built in `amplify-lambda/domain.tf` (replaces
  `serverless-domain-manager`): EDGE `aws_api_gateway_domain_name` + root
  `aws_api_gateway_base_path_mapping` + A/AAAA `aws_route53_record`, gated by
  `var.custom_domain_enabled`. ACM cert (us-east-1) and hosted zone are
  auto-discovered by domain name or supplied via `var.api_custom_domain_certificate_arn`
  / `var.route53_zone_id`. **Manual import required** — domain-manager created
  these via the AWS SDK (not CloudFormation), so they are NOT in `gen-imports.sh`;
  import commands are in the `domain.tf` header. Cutover still pending a real plan.
- [x] **Per-stage tfvars** — `envs/{dev,staging,prod}.tfvars` (staging/prod are
  templates; fill `dep_name` from the uncommitted `var/<stage>-var.yml`).
- **litellm layer is OUT OF SCOPE** — `amplify-lambda-js/serverless.yml` defines no
  `layers:` block and attaches no litellm layer to any function. The standalone
  Python litellm layer is built/published out-of-band by `build-python-litellm-layer.sh`
  (a manual ops script) and is not part of the Serverless-managed stack, so it is
  intentionally not represented in Terraform. Migrating it would add infrastructure
  Serverless does not manage and could change runtime behavior; keep it as a manual
  step (or track it separately) until explicitly in scope.
- [ ] **Phase 6 — Remove Serverless v3**
  - [ ] Delete all `serverless.yml`, `serverless-compose.yml`.
  - [ ] Remove `serverless` + plugin devDependencies from `package.json`.
  - [ ] Update `README.md` + `scripts/` docs to Terraform commands.
  - [ ] Replace any CI/CD `serverless deploy` with `terraform apply`.

## Risks & mitigations

- **Resource recreation = data loss / downtime** → disciplined `terraform import`
  + empty-diff verification; back up DynamoDB/S3 before any `apply`.
- **Shared API stage thrash** (many modules add methods to one API) → centralize
  the `aws_api_gateway_deployment`; feed redeploy triggers from all route modules.
- **Layer ARN churn** → pin layer versions; wire ARNs through variables/SSM.
- **Cross-service ordering** → encode `serverless-compose` `dependsOn` as module
  `depends_on`.

## What I need from you (Phase 0)

The scaffold is in place (`terraform/`), with `data-disclosure` authored end-to-end
as the reference service. To verify it against your live environment and produce an
empty-diff `plan`, I need read-only output from your deployed stage(s):

1. **Confirm the shared REST API export source:**
   ```bash
   aws cloudformation list-exports \
     --query "Exports[?starts_with(Name,'dev-RestApi')].[Name,Value]" --output table
   ```
2. **data-disclosure stack resource inventory** (logical → physical IDs):
   ```bash
   aws cloudformation describe-stack-resources \
     --stack-name "amplify-<DEP_NAME>-data-disclosure-dev" \
     --query "StackResources[].[LogicalResourceId,ResourceType,PhysicalResourceId]" \
     --output table
   ```
3. The `DEP_NAME` value from `var/dev-var.yml` (and the state bucket / lock table
   names you want, or confirmation to bootstrap them).

Paste #1 and #2 back (or drop the output into `terraform/scripts/import/`). I'll
fill the `.importmap`, then the import script + `terraform plan` confirm we're not
recreating anything. Full details: `terraform/scripts/import/README.md`.

> Also worth confirming during this step: whether `amplify-lambda`'s locally
> created `ApiGatewayRestApi` is actually the shared API or a second one — its
> `describe-stack-resources` output will show this.

