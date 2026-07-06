variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "alert_email" {
  description = "On-call email for alerts"
  type        = string
  default     = "oncall@firstnationalbank.com"
}