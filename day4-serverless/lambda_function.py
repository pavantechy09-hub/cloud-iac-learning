import json
import time
import os

# This code runs ONCE when Lambda container starts (cold start)
print("COLD START: Lambda container initializing")
INIT_TIME = time.time()
DB_CONNECTION = "simulated-db-connection-established"  # expensive operation

def handler(event, context):
    # This code runs on EVERY invocation (warm or cold)
    invoke_time = time.time()

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "Hello from Lambda",
            "container_age_seconds": round(invoke_time - INIT_TIME, 2),
            "request_id": context.aws_request_id,
            "memory_mb": context.memory_limit_in_mb
        })
    }