# Day 4 - Serverless — Lambda, API Gateway, SQS, IAM

## What Was Built
Complete serverless fraud detection service for FirstNational Bank.
Lambda triggered by both API Gateway (HTTP) and SQS (event-driven).
Least-privilege IAM — DynamoDB read + S3 write only.
Cold starts measured and understood.

## Architecture
    curl / payments-service
      ?
    API Gateway HTTP API (route: GET /fraud-check)
      ?
    fraud-check Lambda (Python 3.12)
      ? reads              ? writes
    DynamoDB             S3 fraud-reports
    transactions table   bucket

    payments-service ? SQS fraud-events queue
                              ? (event_source_mapping)
                       fraud-check Lambda (auto-triggered)
                              ? (3 failures)
                       fraud-events-dlq (dead letter queue)

## Files
    lambda_function.py   - Python Lambda handler
    lambda_function.zip  - deployment package
    main.tf              - all resources
    provider.tf          - AWS provider pointing to Floci
    outputs.tf           - API endpoint, queue URLs, Lambda ARN

---

## Concepts Learned

### 1. Lambda Anatomy
    handler(event, context)
      event   = input data (HTTP request, SQS message, etc)
      context = runtime info (request_id, memory_limit, time_remaining)

    Code OUTSIDE handler() = runs ONCE at cold start
      imports, DB connections, ML model loading
      expensive operations — do them once, reuse forever

    Code INSIDE handler() = runs on EVERY invocation
      keep this as light as possible

### 2. IAM — Two Different Permission Types
    Execution Role (aws_iam_role)
      WHO Lambda IS when it runs
      what Lambda CAN DO — call DynamoDB, write S3, log to CloudWatch
      trust policy: lambda.amazonaws.com can assume this role

    Resource Policy (aws_lambda_permission)
      WHO CAN CALL Lambda
      API Gateway, SQS, EventBridge — must be explicitly granted
      without this, API Gateway gets 403 even if role is correct

    These are completely different and both required.
    Execution role = outbound. Resource policy = inbound.

### 3. API Gateway HTTP API vs REST API
    HTTP API (v2)
      cheaper, faster, modern
      payload_format_version = 2.0
      event["requestContext"]["http"]["method"]
      event["requestContext"]["http"]["path"]

    REST API (v1)
      older, more features (usage plans, caching)
      payload_format_version = 1.0
      event["httpMethod"]
      event["path"]

    Common bug: mixing v1 event structure with v2 API
    Always check payload_format_version in your integration

### 4. SQS Event Structure
    event = {
      "Records": [              ? always an array
        {
          "messageId": "...",
          "receiptHandle": "...",  ? used internally to delete message
          "body": "...",           ? YOUR message content as STRING
          "eventSource": "aws:sqs",
          "eventSourceARN": "..."
        }
      ]
    }

    body is always a STRING — must json.loads() it
    Forgetting json.loads() is the most common SQS Lambda bug

### 5. SQS + DLQ Pattern
    fraud-events queue
      maxReceiveCount = 3
      "try processing 3 times, then give up"

    fraud-events-dlq
      receives failed messages after 3 attempts
      on-call engineer investigates DLQ messages
      prevents poison pill messages blocking the queue

### 6. Least-Privilege IAM Policy
    Only grant what the function actually needs:
      dynamodb:GetItem, Query on transactions table ONLY
      s3:PutObject on fraud-reports bucket ONLY

    NOT allowed:
      dynamodb:Scan       too expensive
      dynamodb:DeleteItem never delete financial records
      s3:GetObject        fraud service only writes
      s3:DeleteObject     never delete evidence

    Each Statement has a Sid (ReadTransactions, WriteFraudReports)
    Makes policy self-documenting for auditors

### 7. Cold Starts — Proven with Real Data
    Invocation 1: container_age = 0.0s   COLD START
    Invocation 2: container_age = 3.85s  WARM
    Invocation 3: container_age = 7.59s  WARM

    Cold start = Lambda booting a new container
      runs initialization code (imports, connections)
      user experiences extra latency 100ms - 2 seconds

    Warm invocation = existing container reused
      only handler() runs
      millisecond response

    Solutions:
      Provisioned Concurrency = keep N containers pre-warmed
      Scheduled warmup = ping every 5 mins (poor man solution)
      Optimize package = smaller ZIP, fewer imports

### 8. filebase64sha256
    source_code_hash = filebase64sha256("lambda_function.zip")
    Terraform computes ZIP hash
    If code changes ? hash changes ? Terraform redeploys
    Without this, Terraform would not know code changed

---

## CLI Commands Used
    # Invoke Lambda directly
    aws lambda invoke --function-name fraud-check --cli-binary-format raw-in-base64-out --payload '{}' response.json

    # Send SQS message
    aws sqs send-message --queue-url "http://localhost:4566/000000000000/fraud-events" --message-body '...'

    # Check logs
    aws logs describe-log-streams --log-group-name /aws/lambda/fraud-check --order-by LastEventTime --descending
    aws logs get-log-events --log-group-name /aws/lambda/fraud-check --log-stream-name "stream-name"

    # DynamoDB operations
    aws dynamodb put-item --table-name transactions --item file://item.json
    aws dynamodb get-item --table-name transactions --key file://key.json

    # S3 operations
    aws s3 cp file.json s3://fraud-reports-dev/reports/
    aws s3 ls s3://fraud-reports-dev/reports/

---

## Issues Faced and Fixes
| Issue | Cause | Fix |
|-------|-------|-----|
| path unknown in response | Wrong payload format version | Use event["requestContext"]["http"]["path"] for v2.0 |
| JSON parsing error in CLI | PowerShell strips quotes | Use file://item.json instead of inline JSON |
| Plugin cache dir not found | Missing directories | mkdir .terraform-plugins and .terraform-data |

---

## Interview Questions and Answers

Q1: What is a Lambda cold start and how do you fix it?
A cold start happens when Lambda boots a new container to handle a request.
Code outside the handler runs once — imports, DB connections, model loading.
The user experiences extra latency of 100ms to 2 seconds. Fix with
Provisioned Concurrency which keeps N containers pre-warmed at all times.
For payment flows this is non-negotiable — users cannot wait 2 seconds
for a transfer to start.

Q2: What is the difference between Lambda execution role and resource policy?
The execution role controls what Lambda CAN DO — call DynamoDB, write S3,
log to CloudWatch. The resource policy controls who CAN CALL Lambda —
API Gateway, SQS, EventBridge must be explicitly granted permission via
aws_lambda_permission. Both are required. Forgetting the resource policy
means API Gateway gets 403 even if the execution role is perfectly correct.

Q3: What is the SQS event structure in a Lambda handler?
SQS delivers a Records array even for a single message. Each record has
a body field which is always a string — you must call json.loads() on it
to get a Python dict. The receiptHandle is used internally by Lambda to
delete the message after successful processing. maxReceiveCount controls
how many times Lambda retries before sending to the dead letter queue.

Q4: What is a dead letter queue and why is it important?
A DLQ receives messages that failed processing after maxReceiveCount
attempts. Without a DLQ, failed messages loop forever blocking the queue.
With a DLQ, failed messages are isolated for investigation without affecting
new messages. For a bank, a failed fraud check message in the DLQ means
the on-call team can investigate the specific transaction that caused the
failure without any data loss.

Q5: How does Terraform know when Lambda code has changed?
Terraform uses filebase64sha256() to compute a hash of the ZIP file.
If the code changes and you re-zip, the hash changes, and Terraform
detects the diff and redeploys the function. Without this, Terraform
would see the filename unchanged and skip the update.

Q6: What is least-privilege IAM and how do you implement it for Lambda?
Least privilege means granting only the exact permissions needed — nothing
more. For a fraud Lambda, that means dynamodb:GetItem and Query on the
specific transactions table, and s3:PutObject on the specific fraud-reports
bucket. No Scan (too expensive), no Delete (financial records are immutable),
no cross-bucket access. Each statement has a Sid making it self-documenting
for security auditors. If the function is compromised the blast radius is
minimal — the attacker can only read transactions and write reports.

Q7: What is the difference between API Gateway HTTP API and REST API?
HTTP API is v2 — cheaper, faster, simpler. Payload format version 2.0
delivers the HTTP method and path inside event.requestContext.http.
REST API is v1 — older, more features like usage plans, request caching,
WAF integration. Payload format 1.0 delivers httpMethod and path at the
top level of the event. The most common bug is writing v1 event parsing
code for a v2 HTTP API — path returns unknown because the fields are
in a different location.