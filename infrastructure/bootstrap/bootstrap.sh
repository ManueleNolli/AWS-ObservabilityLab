#!/usr/bin/env bash
# Sets up the bootstrap stack in the AWS account you're logged into, then applies it. Safe to re-run:
#   - first run in an account: creates the state bucket with local state, then moves the state into it
#   - local state left over:   moves it into the bucket
#   - otherwise:               connects to the state in the bucket and applies any changes
#
# Usage: AWS_PROFILE=<profile> ./bootstrap.sh
# Optional: TF_VAR_region, TF_VAR_project, TF_VAR_github_repository (defaults in variables.tf).
set -euo pipefail
cd "$(dirname "$0")"

region="${TF_VAR_region:-eu-central-2}"
project="${TF_VAR_project:-observability-lab}"

account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${project}-tfstate-${account_id}"
backend_config=(-backend-config="bucket=${bucket}" -backend-config="region=${region}")

echo "Account ${account_id}, state bucket ${bucket} (${region})"

bucket_exists=true
aws s3api head-bucket --bucket "$bucket" --region "$region" >/dev/null 2>&1 || bucket_exists=false

if [[ "$bucket_exists" == false || -s terraform.tfstate ]]; then
  # An override file replaces the backend block in backend.tf without editing it. Initialising with
  # the local backend first lets the migration below find the local state.
  trap 'rm -f backend_override.tf' EXIT
  printf 'terraform {\n  backend "local" {}\n}\n' >backend_override.tf
  terraform init -reconfigure -input=false

  if [[ "$bucket_exists" == false ]]; then
    echo "Bucket not found: creating it with local state first."
    terraform apply
  fi
  rm backend_override.tf

  echo "Moving local state into s3://${bucket}/bootstrap/"
  terraform init -migrate-state -force-copy -input=false "${backend_config[@]}"

  # Only delete the local copy once the state in the bucket matches what exists in AWS.
  if ! terraform plan -detailed-exitcode -input=false >/dev/null; then
    echo "Plan against the migrated state isn't clean; keeping the local state files." >&2
    exit 1
  fi
  rm -f terraform.tfstate terraform.tfstate.*backup
  echo "State migrated, local copy removed."
else
  terraform init -reconfigure -input=false "${backend_config[@]}"
fi

terraform apply
