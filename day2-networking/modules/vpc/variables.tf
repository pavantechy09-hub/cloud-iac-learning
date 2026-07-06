variable "environment" {
    description = "Environment name"
    type        = string
    default     = "dev"
}

variable "vpc_cidr" {
    description     = "CIDR block for the VPC"
    type            = string
    default         = "10.0.0.0/16"
}
variable "public_subnet_cidr" {
    description = "CIDR for public subnet"
    type        = string
    default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
    description = "CIDR for private subnet"
    type        = string
    default     = "10.0.2.0/24"
}

variable "data_subnet_cidr" {
    description = "CIDR for data subnet"
    type        = string
    default     = "10.0.2.0/24"
}

variable "az" {
    description = "Availability zone"
    type        = string
    default     = "us-east-1a"
}