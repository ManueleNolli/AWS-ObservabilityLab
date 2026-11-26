# Partial configuration: bucket and region depend on the AWS account, so bootstrap.sh passes them
# to terraform init with -backend-config.
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
