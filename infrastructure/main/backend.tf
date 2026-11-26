# Partial configuration: bucket and region depend on the AWS account, so they're passed to
# terraform init with -backend-config (see the bootstrap stack's outputs).
terraform {
  backend "s3" {
    key          = "main/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
