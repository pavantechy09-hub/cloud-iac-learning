output "db_endpoint" {
  value = aws_db_instance.accounts_db.endpoint
}

output "db_name" {
  value = aws_db_instance.accounts_db.db_name
}

output "db_username" {
  value = aws_db_instance.accounts_db.username
}
output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}
