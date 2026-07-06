output "vpc_id" {
  value = module.vpc.vpc_id
}

output "fraud_queue_url" {
  value = aws_sqs_queue.fraud_events.id
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "private_dns_zone" {
  value = aws_route53_zone.private.name
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}