resource "aws_sns_topic" "alerts" {
  name = "bank-platform-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "oncall@firstnationalbank.com"
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "fraud-check-errors"
  alarm_description   = "Lambda error rate too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "fraud-check"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "fraud-check-slow"
  alarm_description   = "Lambda taking too long"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 10000
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "fraud-check"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "fraud-check-throttled"
  alarm_description   = "Lambda being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "fraud-check"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "sqs_depth" {
  alarm_name          = "fraud-queue-backing-up"
  alarm_description   = "Too many messages in fraud queue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = "fraud-events"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "accounts-db-cpu-high"
  alarm_description   = "RDS CPU too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "accounts-db"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "accounts-db-low-storage"
  alarm_description   = "RDS free storage below 4GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 4294967296
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "accounts-db"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# # Dashboard - not supported in Floci, works on real AWS
# resource "aws_cloudwatch_dashboard" "bank_platform" {
#   dashboard_name = "bank-platform-overview"
# 
#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type = "metric"
#         properties = {
#           title   = "Lambda Errors"
#           period  = 300
#           stat    = "Sum"
#           metrics = [["AWS/Lambda", "Errors", "FunctionName", "fraud-check"]]
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "Lambda Duration p99"
#           period  = 300
#           stat    = "p99"
#           metrics = [["AWS/Lambda", "Duration", "FunctionName", "fraud-check"]]
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "SQS Queue Depth"
#           period  = 300
#           stat    = "Average"
#           metrics = [["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "fraud-events"]]
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           title   = "RDS CPU"
#           period  = 300
#           stat    = "Average"
#           metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "accounts-db"]]
#         }
#       }
#     ]
#   })
# }