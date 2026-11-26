variable "name" {
  description = "Name of the service, and prefix of the ALB, roles and log group."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the ALB and the tasks."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the ALB and the tasks, in at least two zones."
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster the service runs in."
  type        = string
}

variable "image" {
  description = "Full image URI, with its tag."
  type        = string
}

variable "desired_count" {
  description = "Number of tasks. Two or more spreads them across zones."
  type        = number
  default     = 2
}
