# VPC across two availability zones. Public subnets only hold the NAT gateways; the ALB, the tasks and
# the VPC endpoints live in the private subnets.

locals {
  # The first two zones of the region, so the same code works in every region.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"

  # Regular zones only, not Local or Wavelength Zones.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.9"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  # Public /24s for the NAT gateways; private /20s for everything else. With 10.0.0.0/16: public
  # 10.0.0.0 and 10.0.1.0, private 10.0.16.0 and 10.0.32.0.
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(var.cidr, 8, i)]
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.cidr, 4, i + 1)]

  # One NAT gateway per zone: losing a zone doesn't cut the other one off.
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  # All traffic, accepted and rejected, aggregated every minute.
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = 7
}

# Keeps AWS traffic off the NAT gateways: S3 (ECR image layers live there) through a free gateway
# endpoint, ECR and CloudWatch Logs through interface endpoints. Private DNS makes the normal service
# hostnames resolve to the endpoints, so nothing else needs configuring.
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.9"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_security_group      = true
  security_group_name_prefix = "${var.name}-vpc-endpoints-"
  security_group_description = "HTTPS from the VPC to the interface endpoints"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from the VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
    }
  }
}
