resource "aws_s3_bucket" "app_bucket" {
    bucket = "myapp-remote-state-demo"

    tags = {
        Environment = "dev"
        ManagedBy   = "dev"
    }
}