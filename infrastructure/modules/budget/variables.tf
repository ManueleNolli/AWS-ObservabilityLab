variable "name" {
  description = "Budget name."
  type        = string
}

variable "limit_usd" {
  description = "Monthly limit in USD."
  type        = number
}

variable "email" {
  description = "Address that receives the alerts."
  type        = string
}
