resource "aws_s3_bucket" "my_first_bucket"{
    bucket = "myapp-${terraform.workspace}-bucket"

    tags = {
        Environment = terraform.workspace
        ManagedBy   = "terraform"
    }
}

resource "aws_s3_bucket_versioning" "my_first_bucket" {
    bucket = aws_s3_bucket.my_first_bucket.id

    versioning_configuration {
        status = "Enabled"
    }
}