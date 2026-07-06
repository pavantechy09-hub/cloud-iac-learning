resource "aws_iam_role" "lambda_exec" {
  name = "fraud-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "fraud_check" {
  function_name = "fraud-check"
  filename       = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
  handler        = "lambda_function.handler"
  runtime        = "python3.12"
  role           = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      ENVIRONMENT = "dev"
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
resource "aws_apigatewayv2_api" "fraud_api" {
  name          = "fraud-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.fraud_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.fraud_check.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "fraud_route" {
  api_id    = aws_apigatewayv2_api.fraud_api.id
  route_key = "GET /fraud-check"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.fraud_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fraud_check.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.fraud_api.execution_arn}/*/*"
}

resource "aws_sqs_queue" "fraud_dlq" {
  name = "fraud-events-dlq"
}

resource "aws_sqs_queue" "fraud_events" {
  name = "fraud-events"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.fraud_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.fraud_events.arn
  function_name    = aws_lambda_function.fraud_check.arn
  batch_size       = 5
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "lambda-sqs-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.fraud_events.arn
    }]
  })
}

resource "aws_dynamodb_table" "transactions" {
  name         = "transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transactionId"

  attribute {
    name = "transactionId"
    type = "S"
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "fraud_reports" {
  bucket = "fraud-reports-dev"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "lambda_least_privilege" {
  name = "lambda-least-privilege"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTransactions"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.transactions.arn
      },
      {
        Sid    = "WriteFraudReports"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.fraud_reports.arn}/*"
      }
    ]
  })
}
