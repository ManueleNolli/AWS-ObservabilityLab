# Infrastructure

Terraform for running the Observability Lab on AWS. Everything is code: nothing is created by hand
in the console. The only manual work is logging in and running one script once per AWS account.

## Layout

| Path | Contents |
| --- | --- |
| `bootstrap/` | What has to exist before anything else: the state bucket, the GitHub OIDC provider, the CI roles, the ECR repositories and a budget alert. Applied from your laptop |
| `main/` | The lab itself: network, ALB, Fargate, S3, CloudFront, monitoring. Applied by CI, destroyed when not in use |
| `modules/` | Building blocks used by the stacks |
| `images/` | Dockerfiles and AWS config for the monitoring images: Prometheus, Loki, Grafana, Fluent Bit |

## Why two stacks

Terraform needs a state bucket and credentials before it can run, and those are what we want
Terraform to create. The bootstrap stack breaks the loop: it starts with local state, creates the
bucket, then moves its own state into it. From then on both stacks keep their state in the bucket:

| Stack | State key | Applied by |
| --- | --- | --- |
| bootstrap | `bootstrap/terraform.tfstate` | You, with `bootstrap/bootstrap.sh` |
| main | `main/terraform.tfstate` | GitHub Actions, through the CI roles |

## Design decisions

| Topic | Decision | Why |
| --- | --- | --- |
| Credentials | IAM Identity Center locally, GitHub OIDC in CI; no long-lived access keys anywhere | Short-lived credentials only |
| CI permissions | The CI roles are owned by the bootstrap stack, which only you apply | CI can't widen its own permissions |
| Deploying | The main stack is deployed and destroyed by manually triggered workflows, from `main` only | Nothing reaches AWS without a deliberate action on reviewed code |
| Environments | One | It's a lab |
| Region | One `region` variable for every resource, default `eu-central-2` (Zurich) | Managed Grafana isn't in Zurich, so `managed` mode runs in `eu-central-1` (Frankfurt) |
| Domain | None: the default `*.cloudfront.net` URL | Only needed to check that everything works |
| Lifecycle | The main stack is destroyed when not in use; the bootstrap stays | The bootstrap costs cents; Fargate, the ALB and CloudFront don't |
| Budget | In the bootstrap stack, not the main one | It keeps watching the account while the main stack is destroyed, or half-destroyed |
| Images | ECR in the bootstrap stack, built by their own workflow, which Deploy runs first | Images survive a destroy; a deploy always has its commit's images |
| Image tags | The git commit SHA, immutable, one plain image per tag (no provenance attestation); the last 10 images are kept | Every deploy points at exactly one commit, and only deployable images count towards the 10 |
| Image region | Replicated from the bootstrap region to `eu-central-1` | `managed` mode deploys to Frankfurt and pulls from its own region |
| Network | `terraform-aws-modules/vpc`, 2 zones, a NAT gateway per zone; only the NAT gateways are in public subnets | Close to a production layout: nothing but CloudFront reaches the app |
| AWS traffic | S3 gateway endpoint and ECR and CloudWatch Logs interface endpoints | Image pulls and logs stay inside the VPC instead of going through the NAT gateways |
| Flow logs | All traffic, to CloudWatch Logs, kept 7 days | Shows what talks to what, e.g. tasks reaching ECR through the endpoints |
| Backend | 2 Fargate tasks (one per zone), ARM64, 0.25 vCPU / 0.5 GB, behind an internal ALB | Real layout, smallest Fargate size, ARM is cheaper |
| ALB | Internal, plain HTTP, reachable only from CloudFront's origin-facing addresses | No domain, so no certificate; the traffic stays on AWS's network |
| Public entry | One CloudFront distribution: the frontend from a private S3 bucket (Origin Access Control), `/api/*` and `/grafana/*` from the ALB through a VPC origin | One URL, no CORS, nothing else public |
| Edge locations | `PriceClass_100`: Europe and North America | The cheapest class |
| WAF, CDN logs | None | WAF costs from ~$5/month before traffic; logs are left to the monitoring |
| Frontend build | In Deploy, after apply: built, synced to the bucket, `index.html` invalidated | The bucket only exists after apply |
| Rollout | Circuit breaker with rollback; Deploy waits for the service to be stable | A broken image fails Deploy instead of crash-looping behind a green run |
| Container logs | CloudWatch Logs, kept 7 days; Container Insights off | Works through the Logs endpoint; our own monitoring covers the metrics |
| Monitoring config | Baked into our own images, built with the backend | Versioned with the code; nothing pulls from Docker Hub at runtime |
| Service discovery | Cloud Map private DNS, `observability.internal` | Prometheus scrapes every backend task by IP; services reach each other by name |
| Backend logs (self-hosted) | FireLens: a Fluent Bit sidecar ships to Loki, with a copy in CloudWatch | Fargate has no Docker socket for Alloy to read |
| Storage | Loki in S3; Prometheus on the task's disk; Grafana stateless | Loki's recommended setup; every Destroy wipes the data anyway |
| Grafana access | Anonymous Viewer, login disabled | Dashboards are public and read-only; nobody can change them |

## Prerequisites

| Tool | Why |
| --- | --- |
| Terraform ≥ 1.10 | S3 native state locking (`use_lockfile`) |
| AWS CLI v2 | Identity Center login; the scripts use it to find the account and the bucket |
| jq | Used by `bootstrap/destroy.sh` and the repository variables command |
| GitHub CLI (`gh`), optional | Sets the repository variables in one command; the GitHub UI works too |

You also need an IAM Identity Center user with admin access to the AWS account, used for the
bootstrap. No long-lived access keys.

## Deploy everything

From an empty AWS account to the running lab. Steps 1–5 happen once per account; after that, only
step 6.

| Step | Where | Time |
| --- | --- | --- |
| 1. Log in with Identity Center | Your laptop | 2 min |
| 2. Enable the region | Your laptop | ~5 min, mostly waiting |
| 3. Set the budget email | Your laptop | 1 min |
| 4. Run the bootstrap | Your laptop | 2 min |
| 5. Set the repository variables | Your laptop or GitHub | 1 min |
| 6. Run Deploy | GitHub Actions | ~20 min the first time |
| 7. Open the app and Grafana | Browser | |


**1. Log in with Identity Center.** `aws configure sso` asks for the access portal URL, then lets you
pick the account and role. Name the profile, e.g. `observability-lab`:

```bash
aws configure sso
```

```bash
aws sts get-caller-identity --profile observability-lab
```

When the session expires, `aws sso login --profile observability-lab`.

**2. Enable the region.** Zurich (`eu-central-2`), the default, is an opt-in region. Activation
takes a few minutes; wait until the status is `ENABLED`:

```bash
aws account enable-region --region-name eu-central-2 --profile observability-lab
```

```bash
aws account get-region-opt-status --region-name eu-central-2 --profile observability-lab
```

**3. Set the budget email.** Copy `bootstrap/terraform.tfvars.example` to `bootstrap/terraform.tfvars`
(gitignored) and fill in your address.

**4. Run the bootstrap.** It creates the state bucket, the CI roles, the ECR repositories and the
budget:

```bash
AWS_PROFILE=observability-lab ./infrastructure/bootstrap/bootstrap.sh
```

On the first run in an account it creates the bucket with local state, moves the state into the
bucket, checks that `terraform plan` shows no changes, and deletes the local copy. Terraform asks for
confirmation before each apply.

**5. Set the repository variables.** The workflows read the bootstrap's outputs from GitHub
repository variables (table in [Repository variables](#repository-variables)). With the GitHub CLI,
logged in to the repository:

```bash
out="$(AWS_PROFILE=observability-lab terraform -chdir=infrastructure/bootstrap output -json)"
for pair in AWS_PLAN_ROLE_ARN:plan_role_arn AWS_APPLY_ROLE_ARN:apply_role_arn \
  AWS_PUSH_ROLE_ARN:push_role_arn ECR_REPOSITORY_PREFIX:ecr_repository_prefix \
  TF_STATE_BUCKET:state_bucket TF_STATE_REGION:state_region; do
  gh variable set "${pair%%:*}" --body "$(jq -r ".${pair#*:}.value" <<<"$out")"
done
```

Or set them by hand in Settings → Secrets and variables → Actions → Variables.

**6. Run Deploy.** On GitHub: Actions → Deploy → Run workflow, on `main`. Pick the region and the
monitoring mode, leave `image_tag` empty. It builds the commit's images, applies the main stack, waits
until every service is healthy, then builds and uploads the frontend. See
[Deploy and destroy](#deploy-and-destroy) for the inputs.

**7. Open the lab.** The run's summary lists the app's URL (`https://<id>.cloudfront.net`) and, in
`self_hosted` mode, Grafana's (`…/grafana`). Or:

```bash
AWS_PROFILE=observability-lab terraform -chdir=infrastructure/main output
```

That needs the main stack initialised locally first: see [Running it locally](#running-it-locally).

### Bootstrap variables

Set them in `bootstrap/terraform.tfvars` or as `TF_VAR_<name>`.

| Variable | Default | Notes |
| --- | --- | --- |
| `budget_email` | (required) | Receives the budget alerts |
| `budget_limit_usd` | `20` | Monthly limit for the whole account |
| `region` | `eu-central-2` | Region of the state bucket and the ECR repositories |
| `ecr_replica_region` | `eu-central-1` | Region the images are replicated to. Must differ from `region` |
| `project` | `observability-lab` | Name prefix; the bucket is `<project>-tfstate-<account-id>` |
| `github_repository` | `ManueleNolli/AWS-ObservabilityLab` | Repository the CI roles trust. Set it to your fork's `owner/name` |

## Remove everything

Back to an empty account. Run Destroy whenever you stop using the lab: the main stack is billed by the
hour. The bootstrap costs cents a month, so step 2 is only for leaving the account for good.

**1. Run Destroy.** On GitHub: Actions → Destroy → Run workflow, on `main`, and type `destroy`. It
reads the region and mode from the state, so there's nothing else to pick. It takes about 20 minutes,
mostly CloudFront. The frontend and Loki buckets are deleted with their contents.

**2. Remove the bootstrap**, once Destroy has finished:

```bash
AWS_PROFILE=observability-lab ./infrastructure/bootstrap/destroy.sh
```

It refuses while the main stack still has resources or a run holds its lock. It asks you to type the
bucket name, then deletes the CI roles, the OIDC provider, the budget, every image in ECR (both
regions) and the state bucket. Details in [Removing the bootstrap](#removing-the-bootstrap).

**3. Optional clean-up:**

| What | How |
| --- | --- |
| Repository variables | `gh variable delete <name>` for each, or the GitHub UI. Harmless if left: nothing can assume the deleted roles |
| Zurich opt-in | `aws account disable-region --region-name eu-central-2 --profile observability-lab` |
| Service-linked roles | AWS creates them for ECS, ELB and CloudFront VPC origins on first use. They're free and stay; delete them in IAM if you want an untouched account |

## Changing the bootstrap

Edit the code and run `bootstrap.sh` again: it connects to the state in the bucket and applies the
changes. CI can't change the bootstrap stack, so this is always a deliberate local step.

## Removing the bootstrap

```bash
AWS_PROFILE=observability-lab ./infrastructure/bootstrap/destroy.sh
```

Refuses while the main stack still has resources in its state, or while a Deploy or Destroy holds
its lock. Otherwise it asks you to type the bucket
name, moves the state back to a local file, destroys the roles, the OIDC provider, the budget and the
ECR repositories with their images, deletes the replica repositories (ECR creates them itself, so
Terraform doesn't manage them), then empties and deletes the bucket. The bucket has `prevent_destroy`, so a plain
`terraform destroy` can't remove it.

## Images

The **Build images** workflow builds every image on ARM runners and pushes each to ECR as
`<project>/<image>:<commit SHA>`. Deploy runs it as its first job; it can also be run on its own
(Actions → Build images → Run workflow). Like Deploy, it only runs from `main`. If the commit already
has an image, it skips that push, so a Deploy of an already built commit spends seconds on it.

| Image | Built from |
| --- | --- |
| `backend` | `backend/Dockerfile` |
| `prometheus` | `prom/prometheus` + `images/prometheus/prometheus.yml` + the alert rules from `observability/rules/` |
| `loki` | `grafana/loki` + `images/loki/loki.yml` (S3 storage) |
| `grafana` | `grafana/grafana` + the data sources in `images/grafana/` + the dashboards from `observability/dashboards/` |
| `fluent-bit` | AWS for Fluent Bit + `images/fluent-bit/outputs.conf` (Loki and CloudWatch outputs) |

The monitoring config differs from `local/` only where AWS differs: Cloud Map names instead of
compose hostnames, S3 instead of a local disk, FireLens instead of Alloy and the Docker socket.

ECR copies each image to the replica region; the copies get the same settings through a repository
creation template. ECR copies each image to the replica region; the copies get the same settings through a repository
creation template.

The frontend has no image: it's served from S3 as static files.

## Main stack

### Deploy and destroy

Both are GitHub Actions workflows started by hand (Actions → workflow → Run workflow) and only run
from `main`. They plan, write the plan to the run summary, then apply exactly that plan. They share a
concurrency group, so they never run at the same time.

| Workflow | Inputs | Notes |
| --- | --- | --- |
| **Deploy** | `region`, `monitoring_mode`, `image_tag` | Builds the commit's missing images first. Refuses a region other than the one the stack is deployed in |
| **Destroy** | `confirm`: type `destroy` | Reads the region, mode and image tag from the state, so it always targets what is deployed |

Without `image_tag`, Deploy builds and deploys the images of the commit it runs on. With it, Deploy
builds nothing and deploys that tag, which must already be in ECR: that's how to roll back, since ECR
keeps the last 10. In the replica region, Deploy waits a few minutes for ECR to copy new images.
Creating or deleting the CloudFront distribution and its VPC origin takes 10–15 minutes,
so expect Deploy and Destroy to take about 20.

To change region: run Destroy, then Deploy with the new region. Terraform doesn't move resources
between regions; it would create new ones and leave the old ones running, unmanaged.

There's no approval step beyond the typed confirmation: a GitHub Environment would change the OIDC
subject to `…:environment:<name>`, which the apply role doesn't trust.

### Network

| | CIDR | Holds |
| --- | --- | --- |
| VPC | `10.0.0.0/16` | |
| Public subnets | `10.0.0.0/24`, `10.0.1.0/24` | The NAT gateways |
| Private subnets | `10.0.16.0/20`, `10.0.32.0/20` | The ALB, the Fargate tasks, the interface endpoints |

The zones are the first two of the region, looked up at plan time. Flow logs go to the
`/aws/vpc-flow-log/<vpc-id>` log group. The NAT gateways and interface endpoints are billed by the
hour, which is most of the stack's cost while it's deployed.

### What runs

| Service | Tasks | Size | Reached at |
| --- | --- | --- | --- |
| Backend | 2, one per zone | 0.25 vCPU / 0.5 GB + Fluent Bit sidecar | `/api/*` through CloudFront; metrics on `backend.observability.internal:9100` |
| Prometheus | 1 | 0.5 vCPU / 1 GB | `prometheus.observability.internal:9090`, from Grafana only |
| Loki | 1 | 0.5 vCPU / 1 GB | `loki.observability.internal:3100`, from Grafana and Fluent Bit |
| Grafana | 1 | 0.25 vCPU / 0.5 GB | `/grafana` through CloudFront |

The monitoring services only exist in `self_hosted` mode. In `managed` mode the backend logs to
CloudWatch only, and CloudFront serves `/api/*` alone.

Each security group allows only the traffic in the table: CloudFront's origin-facing prefix list to
the ALB, the ALB to the backend and Grafana, Prometheus to the backend's metrics port, Fluent Bit to
Loki, and Grafana to Prometheus and Loki.

After a Deploy, the run summary has the app's URL and Grafana's.

### Running it locally

Initialise it against the bucket created by the bootstrap:

```bash
AWS_PROFILE=observability-lab terraform -chdir=infrastructure/main init \
  -backend-config="bucket=observability-lab-tfstate-<account-id>" \
  -backend-config="region=eu-central-2"
```

| Variable | Default | Notes |
| --- | --- | --- |
| `region` | `eu-central-2` | Region for every resource in the stack |
| `monitoring_mode` | `self_hosted` | `self_hosted` or `managed` |
| `project` | `observability-lab` | Name prefix and `Project` tag |
| `image_tag` | (required) | Image tag, a git SHA. The images must exist in ECR in `region` |

Amazon Managed Grafana isn't available in Zurich. With `monitoring_mode = "managed"`, set `region` to
a region that has it, e.g. `eu-central-1` (Frankfurt); otherwise the plan fails and lists the
supported regions.

## CI access

GitHub Actions gets short-lived credentials through OIDC; no AWS keys are stored in GitHub.

| Role | Trusted for | Permissions |
| --- | --- | --- |
| `<project>-github-plan` | Pull requests and `main` | Read-only, plus the main stack's state |
| `<project>-github-apply` | `main` only | Admin, plus the main stack's state |
| `<project>-github-push` | `main` only | Push to the ECR repositories |

The plan and apply roles are denied changes to the CI roles, the OIDC provider, the state bucket's
settings, the bootstrap state, the ECR repositories (in every region) and the registry's replication
settings. The apply role could still create a new role to get around that; closing the gap
would need a permissions boundary on every role the main stack creates, which a lab doesn't justify.

### Repository variables

The workflows read the bootstrap outputs from GitHub repository variables (Settings → Secrets and
variables → Actions → Variables). They aren't secrets. Print them with
`AWS_PROFILE=observability-lab terraform -chdir=infrastructure/bootstrap output`.

| Variable | Bootstrap output |
| --- | --- |
| `AWS_PLAN_ROLE_ARN` | `plan_role_arn` |
| `AWS_APPLY_ROLE_ARN` | `apply_role_arn` |
| `AWS_PUSH_ROLE_ARN` | `push_role_arn` |
| `ECR_REPOSITORY_PREFIX` | `ecr_repository_prefix` |
| `TF_STATE_BUCKET` | `state_bucket` |
| `TF_STATE_REGION` | `state_region` |

### Checks

Every push and pull request runs `terraform fmt`, `validate` for both stacks and `tflint`
(`.tflint.hcl`). Pull requests and pushes to `main` also run a read-only `terraform plan` of the main
stack with the plan role; the output is in the run's summary.
