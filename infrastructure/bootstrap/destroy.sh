#!/usr/bin/env bash
# Removes the bootstrap stack from the AWS account you're logged into: CI roles, OIDC provider and the
# state bucket with every version in it. Refuses while the main stack still has state in the bucket.
#
# Usage: AWS_PROFILE=<profile> ./destroy.sh
# Optional: TF_VAR_region, TF_VAR_project (defaults in variables.tf).
set -euo pipefail
cd "$(dirname "$0")"

region="${TF_VAR_region:-eu-central-2}"
project="${TF_VAR_project:-observability-lab}"

account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${project}-tfstate-${account_id}"
backend_config=(-backend-config="bucket=${bucket}" -backend-config="region=${region}")

echo "Account ${account_id}, state bucket ${bucket} (${region})"

main_objects="$(aws s3api list-objects-v2 --bucket "$bucket" --region "$region" --prefix main/ --query "length(Contents || \`[]\`)")"
if [[ "$main_objects" != "0" ]]; then
  echo "The main stack still has state in the bucket: destroy it first." >&2
  exit 1
fi

read -rp "This permanently deletes the CI roles, the OIDC provider and ${bucket}. Type the bucket name to continue: " answer
[[ "$answer" == "$bucket" ]] || { echo "Aborted."; exit 1; }

# The bucket holding the state is about to be deleted, so bring the state back to a local file.
terraform init -reconfigure -input=false "${backend_config[@]}"
trap 'rm -f backend_override.tf' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' >backend_override.tf
terraform init -migrate-state -force-copy -input=false

# prevent_destroy stops terraform from deleting the bucket, so it leaves the state and is deleted below.
terraform state rm module.state_bucket
terraform destroy

echo "Emptying and deleting ${bucket}"
versions="$(aws s3api list-object-versions --bucket "$bucket" --region "$region" --output json \
  --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}, Quiet: `true`}')"
if [[ "$(jq '.Objects | length' <<<"$versions")" != "0" ]]; then
  aws s3api delete-objects --bucket "$bucket" --region "$region" --delete "$versions" >/dev/null
fi
aws s3api delete-bucket --bucket "$bucket" --region "$region"

rm -f terraform.tfstate terraform.tfstate.*backup
echo "Bootstrap removed."
