# Day 10 - Capstone Project

## FirstNational Bank — Complete Platform

Single Terraform root module calling all components from Days 1-9.
State stored in S3 remote backend (Day 1 pattern).

## Architecture Deployed

    Network (Day 2):
      VPC 10.0.0.0/16 with 3 subnet tiers
      Public subnet  10.0.1.0/24 - ALB, NAT Gateway
      Private subnet 10.0.2.0/24 - App servers
      Data subnet    10.0.3.0/24 - Databases
      Security groups: alb-sg, app-sg, db-sg (least privilege)
      Internet Gateway + route tables

    Secrets (Day 6):
      Secrets Manager bank/prod/db-password
      Full connection JSON: host, port, username, dbname
      App reads one secret, gets everything needed
      recovery_window_in_days = 7

    Storage (Day 6):
      S3 prod-bank-transaction-archive
      Versioning enabled
      Public access completely blocked

    Application (Day 4):
      SQS prod-fraud-events queue (maxReceiveCount = 3)
      SQS prod-fraud-events-dlq (dead letter queue)
      Lambda execution role with least-privilege:
        dynamodb:GetItem, Query
        secretsmanager:GetSecretValue on specific secret ARN only

    Security (Day 7):
      Route53 private hosted zone bank.internal
      CNAME: accounts-db.bank.internal (stable internal DNS)

    Monitoring (Day 9):
      SNS topic prod-bank-alerts
      Email subscription for on-call engineer
      CloudWatch alarm: SQS queue depth > 100 messages

    Not included (Floci limitation):
      RDS PostgreSQL - proven working in Day 6 independently
      Floci has stability issues with concurrent RDS operations
      On real AWS: add aws_db_instance with storage_encrypted=true,
      multi_az=true, deletion_protection=true

## How to Deploy

    # Set up environment
    . D:\cloud-iac\start-env.ps1

    # Create remote state bucket first
    aws s3 mb s3://terraform-state-backend

    # Deploy
    cd D:\cloud-iac\day10-capstone
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

## Module Structure

    day10-capstone/
      provider.tf    - AWS provider + S3 remote backend
      variables.tf   - environment, vpc_cidr, alert_email
      main.tf        - calls all modules and resources
      outputs.tf     - vpc_id, queue_url, secret_arn, dns_zone

## Key Design Decisions

    Remote state in S3:
      Team of 20 engineers shares same state
      DynamoDB locking prevents simultaneous applies
      S3 versioning enables state rollback

    VPC module reuse:
      Same module from Day 2 called with prod values
      environment = "prod" flows through all resource names and tags
      Zero code duplication from dev to prod

    Least-privilege IAM:
      Lambda role has exactly two permissions
      DynamoDB read on transactions table
      Secrets Manager read on THIS specific secret ARN
      Nothing else - blast radius minimized if compromised

    Private DNS:
      Services call accounts-db.bank.internal not raw RDS hostname
      If DB is replaced, update one CNAME record
      All services automatically use new endpoint

    Dead Letter Queue:
      Failed fraud checks go to DLQ after 3 attempts
      Main queue keeps flowing - poison pill isolated
      On-call engineer investigates only failed transactions

## 10-Day Learning Summary

    Day 1:  Terraform state, plan, apply, workspaces, remote backend
    Day 2:  VPC, subnets, IGW, NAT, SGs, route tables, reusable modules
    Day 3:  Bicep, ARM, VNet, NSG, Key Vault, Functions, APIM, Service Bus
    Day 4:  Lambda, API Gateway, SQS, DLQ, IAM, cold starts
    Day 5:  Kubernetes, kind cluster, RBAC, Secrets, Ingress, NetworkPolicy
    Day 6:  RDS, Secrets Manager, S3 lifecycle, CosmosDB, Azure SQL
    Day 7:  IAM cross-account, Transit Gateway, Route53, Flow Logs, Checkov
    Day 8:  GitHub Actions, OIDC, drift detection, Azure DevOps
    Day 9:  CloudWatch alarms, SNS, Azure Monitor, Log Analytics
    Day 10: Capstone - full platform, interview prep

## Floci Limitations Discovered Across 10 Days

| Feature | Floci | Real AWS |
|---------|-------|----------|
| S3, SQS, SNS, IAM, Lambda | Supported | Supported |
| CloudWatch alarms | Supported | Supported |
| Route53 zones + records | Supported | Supported |
| Secrets Manager | Supported | Supported |
| RDS basic | Partial (stability issues) | Fully supported |
| NAT Gateway | Not supported | Supported |
| VPC Endpoints | Not supported | Supported |
| Transit Gateway | Not supported | Supported |
| VPC Flow Logs | Not supported | Supported |
| CloudWatch dashboard | Not supported | Supported |
| RDS subnet groups | Not supported | Supported |