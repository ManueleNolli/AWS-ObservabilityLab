#!/usr/bin/env bash
# Removes the bootstrap stack from the AWS account you're logged into: CI roles, OIDC provider, budget,
# ECR repositories with their replicas, and the state bucket with every version in it. Refuses while
# the main stack still has state in the bucket.
#
# Usage: AWS_PROFILE=<profile> ./destroy.sh
# Optional: TF_VAR_region, TF_VAR_project, TF_VAR_ecr_replica_region (defaults in variables.tf).
set -euo pipefail
cd "$(dirname "$0")"

region="${TF_VAR_region:-eu-central-2}"
project="${TF_VAR_project:-observability-lab}"
replica_region="${TF_VAR_ecr_replica_region:-eu-central-1}"

account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${project}-tfstate-${account_id}"
backend_config=(-backend-config="bucket=${bucket}" -backend-config="region=${region}")

echo "Account ${account_id}, state bucket ${bucket} (${region})"

# Destroy leaves the main stack's state file behind, empty: check for resources, not for the file.
if aws s3api head-object --bucket "$bucket" --region "$region" --key main/terraform.tfstate.tflock >/dev/null 2>&1; then
  echo "The main stack's state is locked: a Deploy or Destroy is running. Wait for it." >&2
  exit 1
fi
main_resources=0
if main_state="$(aws s3 cp "s3://${bucket}/main/terraform.tfstate" - --region "$region" 2>/dev/null)"; then
  main_resources="$(jq '.resources | length' <<<"$main_state")"
fi
if [[ "$main_resources" != "0" ]]; then
  echo "The main stack still has ${main_resources} resources: run the Destroy workflow first." >&2
  exit 1
fi

read -rp "This permanently deletes the CI roles, the OIDC provider, every image in ECR and ${bucket}. Type the bucket name to continue: " answer
[[ "$answer" == "$bucket" ]] || { echo "Aborted."; exit 1; }

# The bucket holding the state is about to be deleted, so bring the state back to a local file.
terraform init -reconfigure -input=false "${backend_config[@]}"
trap 'rm -f backend_override.tf' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' >backend_override.tf
terraform init -migrate-state -force-copy -input=false

# prevent_destroy stops terraform from deleting the bucket, so it leaves the state and is deleted below.
terraform state rm module.state_bucket
terraform destroy

# ECR created the replicas itself, so Terraform doesn't know them. Replication is gone by now, so
# nothing recreates them.
replicas="$(aws ecr describe-repositories --region "$replica_region" --output text \
  --query "repositories[?starts_with(repositoryName, '${project}/')].repositoryName")"
for repository in $replicas; do
  echo "Deleting replica ${repository} (${replica_region})"
  aws ecr delete-repository --repository-name "$repository" --region "$replica_region" --force >/dev/null
done

echo "Emptying and deleting ${bucket}"
# shellcheck disable=SC2016 # backticks are JMESPath literals, not shell
versions="$(aws s3api list-object-versions --bucket "$bucket" --region "$region" --output json \
  --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}, Quiet: `true`}')"
if [[ "$(jq '.Objects | length' <<<"$versions")" != "0" ]]; then
  aws s3api delete-objects --bucket "$bucket" --region "$region" --delete "$versions" >/dev/null
fi
aws s3api delete-bucket --bucket "$bucket" --region "$region"

rm -f terraform.tfstate terraform.tfstate.*backup
echo "Bootstrap removed."
