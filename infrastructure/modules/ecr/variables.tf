variable "name_prefix" {
  description = "Prefix of the repository names: repositories are <name_prefix>/<name>."
  type        = string
}

variable "repositories" {
  description = "Names of the repositories, without the prefix."
  type        = set(string)

  validation {
    condition     = length(var.repositories) > 0
    error_message = "At least one repository is needed."
  }
}

variable "keep_images" {
  description = "Number of images each repository keeps; older ones expire."
  type        = number
  default     = 10
}

variable "replica_region" {
  description = "Region the repositories are replicated to. Must match the aws.replica provider."
  type        = string
}
