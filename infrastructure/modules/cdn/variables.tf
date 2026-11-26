variable "name" {
  description = "Prefix of the bucket, the origin access control and the VPC origin."
  type        = string
}

variable "alb_arn" {
  description = "Internal ALB that serves the dynamic paths."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the internal ALB."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group of the ALB: gets an ingress rule for CloudFront."
  type        = string
}

variable "alb_path_patterns" {
  description = "Paths served by the ALB instead of the bucket, e.g. /api/*."
  type        = list(string)
}
