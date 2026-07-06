resource "aws_s3_bucket" "flow_logs" {
  bucket = "bank-vpc-flow-logs"
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketAcl"
      ]
      Resource = [
        aws_s3_bucket.flow_logs.arn,
        "${aws_s3_bucket.flow_logs.arn}/*"
      ]
    }]
  })
}

# Flow Log - not supported in Floci, works on real AWS
# resource "aws_flow_log" "prod" {
#   vpc_id               = aws_vpc.prod.id
#   traffic_type         = "ALL"
#   iam_role_arn         = aws_iam_role.flow_logs.arn
#   log_destination      = aws_s3_bucket.flow_logs.arn
#   log_destination_type = "s3"
# }
resource "aws_s3_bucket_public_access_block" "flow_logs_block" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
