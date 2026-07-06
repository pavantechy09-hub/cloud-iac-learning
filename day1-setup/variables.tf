variable "bucket_name" {
    description = "Name of the s3 bucket"
    type        = string 
    default     = "my-first-terraform-bucket"
}

variable "environment"{
    description = "Environment name"
    type        = string
    default     = "dev"
}