# ---------------------------------------------
# NETWORK LAYER (Day 2)
# ---------------------------------------------
module "vpc" {
  source = "../day2-networking/modules/vpc"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  data_subnet_cidr    = "10.0.3.0/24"
  az                  = "us-east-1a"
}

# ---------------------------------------------
# SECRETS (Day 6 pattern - no RDS reference)
# ---------------------------------------------
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "bank/${var.environment}/db-password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    host     = "accounts-db.bank.internal"
    port     = 5432
    username = "bankadmin"
    dbname   = "accounts"
  })
}

# ---------------------------------------------
# STORAGE (Day 6)
# ---------------------------------------------
resource "aws_s3_bucket" "transaction_archive" {
  bucket = "${var.environment}-bank-transaction-archive"
}

resource "aws_s3_bucket_versioning" "transaction_archive" {
  bucket = aws_s3_bucket.transaction_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "transaction_archive" {
  bucket                  = aws_s3_bucket.transaction_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------
# APPLICATION LAYER (Day 4)
# ---------------------------------------------
resource "aws_sqs_queue" "fraud_dlq" {
  name = "${var.environment}-fraud-events-dlq"
}

resource "aws_sqs_queue" "fraud_events" {
  name = "${var.environment}-fraud-events"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.fraud_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-fraud-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_least_privilege" {
  name = "${var.environment}-lambda-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTransactions"
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = "*"
      },
      {
        Sid    = "ReadSecret"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

# ---------------------------------------------
# SECURITY LAYER (Day 7)
# ---------------------------------------------
resource "aws_route53_zone" "private" {
  name = "bank.internal"
  tags = { Environment = var.environment }
}

resource "aws_route53_record" "accounts_db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "accounts-db.bank.internal"
  type    = "CNAME"
  ttl     = 300
  records = ["localhost"]
}

# ---------------------------------------------
# MONITORING LAYER (Day 9)
# ---------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-bank-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "sqs_depth" {
  alarm_name          = "${var.environment}-fraud-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"
  dimensions          = { QueueName = aws_sqs_queue.fraud_events.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}