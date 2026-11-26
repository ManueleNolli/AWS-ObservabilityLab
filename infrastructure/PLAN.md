# Infrastructure plan

Terraform for running the Observability Lab on AWS. This page is the plan for the first phase: getting
from an empty AWS account to manual deploy and destroy pipelines, with as few manual operations as
possible.

## Decisions

| Topic | Decision | Why |
| --- | --- | --- |
| Bootstrap | A separate Terraform stack, `infrastructure/bootstrap/`, applied once from a laptop | One IaC tool for everything; no resources created by hand in the console |
| State | S3 bucket, versioned and encrypted, locked with `use_lockfile = true` | S3 native locking, so no DynamoDB table |
| Local credentials | IAM Identity Center (`aws sso login`), no long-lived access keys | Short-lived credentials; root is only used to set up Identity Center |
| CI credentials | GitHub OIDC, no AWS keys stored in GitHub | CI gets short-lived credentials per run |
| CI roles | A read-only **plan** role and an **apply** role, both owned by the bootstrap stack | CI can't widen its own permissions; changing them needs a deliberate local apply |
| Who can deploy | Deploy and destroy run on manual trigger only, from `main` only | The apply role trusts `refs/heads/main` and nothing else |
| Environments | One | It's a lab |
| Region | One `region` variable for every resource, default `eu-central-2` (Zurich) | Amazon Managed Grafana isn't available in Zurich: for `monitoring_mode = "managed"`, set `eu-central-1` (Frankfurt) |
| Domain | None, the default `*.cloudfront.net` URL | Only needed to check that everything works |
| Lifecycle | The main stack is destroyed when not in use; the bootstrap stack stays | The bootstrap resources cost cents; Fargate, ALB and CloudFront don't |

## Two stacks

| Stack | Applied by | State | Contents |
| --- | --- | --- | --- |
| `bootstrap/` | You, once, from your laptop | Starts local, then migrated into the bucket it creates | State bucket, GitHub OIDC provider, plan and apply roles |
| main | CI (deploy and destroy workflows) | State bucket | Everything else: ECR, network, ALB, Fargate, S3, CloudFront, monitoring |

The bootstrap stack solves the chicken-and-egg problem: Terraform needs a state bucket and
credentials before it can run, and those are what we want Terraform to create.

## Steps

- [x] **1. Identity Center profile on this PC**
- [x] **2. Bootstrap stack:** state bucket, OIDC provider, plan and apply roles
- [x] **3. Apply the bootstrap and move its state into the bucket it created:** `bootstrap/bootstrap.sh` (and `bootstrap/destroy.sh` to remove it)
- [ ] **4. Main stack skeleton:** S3 backend, `region` variable, default tags, budget alert
- [ ] **5. CI checks:** `terraform fmt`, `validate` and `tflint` on every PR, plus a read-only `plan`
- [ ] **6. Deploy and destroy workflows:** manual trigger, `main` only; destroy asks for confirmation
- [ ] **7. Documentation:** bootstrap, deploy, destroy, switching region

After this phase come the AWS resources themselves: ECR, network, ALB and Fargate, then S3 and
CloudFront, then self-hosted monitoring, then managed monitoring.

### 1. Identity Center profile

Requires the AWS CLI v2 and a permission set with admin access to the lab account (needed once, for
the bootstrap).

```bash
aws configure sso
```

It asks for:

| Prompt | Answer |
| --- | --- |
| SSO session name | `observability-lab` |
| SSO start URL | Your Identity Center access portal URL, `https://<something>.awsapps.com/start` |
| SSO region | The region where Identity Center is enabled |
| SSO registration scopes | Leave the default |

A browser window opens to log in. Then pick the account and the role, and answer:

| Prompt | Answer |
| --- | --- |
| Default client Region | `eu-central-2` |
| CLI default output format | `json` |
| Profile name | `observability-lab` |

Check that it works:

```bash
aws sts get-caller-identity --profile observability-lab
```

When the session expires, log in again with:

```bash
aws sso login --profile observability-lab
```

### 2–7

Filled in as each step is done. The final user-facing docs go in `README.md` (step 7).

## Open questions

- A nightly scheduled destroy as a safety net, on top of the manual one? To decide in step 6.
