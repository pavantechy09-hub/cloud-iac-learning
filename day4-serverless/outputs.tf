output "lambda_function_name" {
  value = aws_lambda_function.fraud_check.function_name
}

output "lambda_arn" {
  value = aws_lambda_function.fraud_check.arn
}
output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "sqs_queue_url" {
  value = aws_sqs_queue.fraud_events.id
}

output "dlq_url" {
  value = aws_sqs_queue.fraud_dlq.id
}
