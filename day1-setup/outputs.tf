output "bucket_name" {
    value = aws_s3_bucket.my_first_bucket.id
}

output "bucket_arn" {
    value = aws_s3_bucket.my_first_bucket.arn
}