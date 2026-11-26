output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets, one per zone: for the ALB and the tasks."
  value       = module.vpc.private_subnets
}
