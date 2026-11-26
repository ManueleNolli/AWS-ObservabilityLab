# Infrastructure

Terraform for running the Observability Lab on AWS. Everything is code: nothing is created by hand
in the console. The only manual work is logging in and running one script once per AWS account.

## Layout

| Path | Contents |
| --- | --- |
| `bootstrap/` | What has to exist before anything else: the state bucket, the GitHub OIDC provider, the CI roles and a budget alert. Applied from your laptop |
| `main/` | The lab itself: ECR, network, ALB, Fargate, S3, CloudFront, monitoring. Applied by CI, destroyed when not in use |
| `modules/` | Building blocks used by the stacks |

## Why two stacks

Terraform needs a state bucket and credentials before it can run, and those are what we want
Terraform to create. The bootstrap stack breaks the loop: it starts with local state, creates the
bucket, then moves its own state into it. From then on both stacks keep their state in the bucket:

| Stack | State key | Applied by |
| --- | --- | --- |
| bootstrap | `bootstrap/terraform.tfstate` | You, with `bootstrap/bootstrap.sh` |
| main | `main/terraform.tfstate` | GitHub Actions, through the CI roles |

## Prerequisites

| Tool | Why |
| --- | --- |
| Terraform ≥ 1.10 | S3 native state locking (`use_lockfile`) |
| AWS CLI v2 | Identity Center login; the scripts use it to find the account and the bucket |
| jq | Used by `bootstrap/destroy.sh` |

You also need an IAM Identity Center user with admin access to the AWS account, used once for the
bootstrap. No long-lived access keys.

## First-time setup

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

**4. Run the bootstrap:**

```bash
AWS_PROFILE=observability-lab ./infrastructure/bootstrap/bootstrap.sh
```

On the first run in an account it creates the bucket with local state, moves the state into the
bucket, checks that `terraform plan` shows no changes, and deletes the local copy. Terraform asks for
confirmation before each apply.

### Bootstrap variables

Set them in `bootstrap/terraform.tfvars` or as `TF_VAR_<name>`.

| Variable | Default | Notes |
| --- | --- | --- |
| `budget_email` | (required) | Receives the budget alerts |
| `budget_limit_usd` | `20` | Monthly limit for the whole account |
| `region` | `eu-central-2` | Region of the state bucket |
| `project` | `observability-lab` | Name prefix; the bucket is `<project>-tfstate-<account-id>` |
| `github_repository` | `ManueleNolli/AWS-ObservabilityLab` | Repository the CI roles trust. Set it to your fork's `owner/name` |

## Changing the bootstrap

Edit the code and run `bootstrap.sh` again: it connects to the state in the bucket and applies the
changes. CI can't change the bootstrap stack, so this is always a deliberate local step.

## Removing the bootstrap

```bash
AWS_PROFILE=observability-lab ./infrastructure/bootstrap/destroy.sh
```

Refuses while the main stack still has state in the bucket. Otherwise it asks you to type the bucket
name, moves the state back to a local file, destroys the roles, the OIDC provider and the budget, then
empties and deletes the bucket. The bucket has `prevent_destroy`, so a plain `terraform destroy`
can't remove it.

## Main stack

Locally, initialise it against the bucket created by the bootstrap:

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

Amazon Managed Grafana isn't available in Zurich. With `monitoring_mode = "managed"`, set `region` to
a region that has it, e.g. `eu-central-1` (Frankfurt); otherwise the plan fails and lists the
supported regions. Destroy the stack before changing `region`: switching recreates everything.

## CI access

GitHub Actions gets short-lived credentials through OIDC; no AWS keys are stored in GitHub.

| Role | Trusted for | Permissions |
| --- | --- | --- |
| `<project>-github-plan` | Pull requests and `main` | Read-only, plus the main stack's state |
| `<project>-github-apply` | `main` only | Admin, plus the main stack's state |

Both roles are denied changes to the CI roles, the OIDC provider, the state bucket's settings and
the bootstrap state. The apply role could still create a new role to get around that; closing the gap
would need a permissions boundary on every role the main stack creates, which a lab doesn't justify.
