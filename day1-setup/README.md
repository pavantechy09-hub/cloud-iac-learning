@'
# Day 1 - Terraform Foundations + AWS with Floci

## Environment Setup

### Tools Installed
- Floci CLI 0.1.4 - local AWS emulator (localhost:4566)
- Docker Desktop 28.1.1 - runs Floci containers
- Terraform v1.15.5 - IaC tool
- AWS CLI - talks to Floci endpoint

### Start Floci Every Day (run these first)
    floci start
    floci doctor
    $env:AWS_ENDPOINT_URL = "http://localhost:4566"
    $env:AWS_ACCESS_KEY_ID = "test"
    $env:AWS_SECRET_ACCESS_KEY = "test"
    $env:AWS_DEFAULT_REGION = "us-east-1"

---

## What Was Completed

### Lab 1 - First Terraform Deploy
- Wrote provider.tf, main.tf, outputs.tf from scratch
- Deployed S3 bucket to Floci
- Full cycle: init, plan -out=tfplan, apply tfplan, destroy

### Lab 2 - State File and Drift
- Read terraform.tfstate and understood every field
- Deleted Terraform bucket manually - drift detected
- Created manual bucket - Terraform was blind to it

### Lab 3 - Variables
- Created variables.tf
- Learned: var.bucket_name vs "var.bucket_name"
- Discovered -/+ forced replacement on immutable attributes

### Lab 4 - Workspaces
- Created dev, staging, prod workspaces
- All 3 deployed simultaneously with same code
- Each workspace has its own isolated state file

### Lab 5 - Remote State
- Created S3 bucket: terraform-state-backend
- State now lives in S3, not on laptop
- No terraform.tfstate file locally after apply

---

## Issues Faced and Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| floci not recognized | PATH not updated | Reopen terminal or set PATH manually |
| terraform not recognized | PATH not updated | $env:PATH += ";path\to\terraform" |
| Docker pipe error | Docker Desktop not running | Start Docker Desktop first |
| S3 virtual-hosted URL error | Missing s3_use_path_style | Add s3_use_path_style = true to provider |
| bucket = "var.bucket_name" | Quotes around variable | Remove quotes: bucket = var.bucket_name |
| Stale plan error | File changed after plan | Always re-run plan after any file change |
| Space in bucket name | Copy-paste issue | Use single-quote heredoc in PowerShell |

---

## Key Files

### provider.tf
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }
    provider "aws" {
      region                      = "us-east-1"
      access_key                  = "test"
      secret_key                  = "test"
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      s3_use_path_style           = true
      endpoints {
        s3 = "http://localhost:4566"
      }
    }

### main.tf - Workspaces Version
    resource "aws_s3_bucket" "my_first_bucket" {
      bucket = "myapp-${terraform.workspace}-bucket"
      tags = {
        Environment = terraform.workspace
        ManagedBy   = "terraform"
      }
    }
    resource "aws_s3_bucket_versioning" "my_first_bucket" {
      bucket = aws_s3_bucket.my_first_bucket.id
      versioning_configuration {
        status = "Enabled"
      }
    }

---

## Core Concepts

### Terraform Lifecycle
    init        = downloads providers into .terraform/
    plan -out   = shows what will change, saves to file
    apply file  = executes exactly the saved plan
    destroy     = tears down in reverse dependency order

### State File
    terraform.tfstate = Terraforms memory
    serial number increments every apply
    lineage = unique ID, never changes
    dependencies = controls destroy order

### Drift
    Terraform resource deleted manually = DETECTED next plan
    Resource created manually outside Terraform = INVISIBLE
    Rule: never touch Terraform resources manually

### Variables
    var.name                    = variable reference (correct)
    "var.name"                  = literal string (bug)
    "prefix-${var.name}-suffix" = string interpolation (correct)

### Workspaces
    default:  terraform.tfstate
    dev:      terraform.tfstate.d/dev/terraform.tfstate
    staging:  terraform.tfstate.d/staging/terraform.tfstate
    prod:     terraform.tfstate.d/prod/terraform.tfstate
    Same code. Different state. Zero changes between envs.

### Remote State
    Local  = only you see it, lost if laptop dies
    Remote = team shares it, S3 versioning = history
    Always use S3 + DynamoDB locking in enterprise

---

## Interview Questions and Answers

Q1: What is Terraform state and why does it exist?
State is Terraforms memory of what it created. It maps .tf resource blocks
to real infrastructure IDs and attributes. Without state Terraform cannot
know what already exists, what changed, or what to destroy.

Q2: What happens if two engineers run terraform apply simultaneously?
Without locking they corrupt the state file. Fix is DynamoDB locking with
S3 backend. First apply acquires lock, second waits or fails with lock error.

Q3: What is drift in Terraform?
Drift is when real infrastructure no longer matches Terraform state. Manually
deleting a Terraform resource gets detected on next plan. Manually creating
outside Terraform is invisible. Use IaC-only policies to prevent drift.

Q4: What is the difference between terraform plan and terraform apply?
Plan shows what WILL happen without doing it. Apply executes the changes.
Always use plan -out=tfplan then apply tfplan to guarantee what you reviewed
is exactly what gets applied.

Q5: What does -/+ mean in a Terraform plan?
Destroy and recreate. Some attributes are immutable like S3 bucket names.
Changing them destroys the old resource and creates a new one. In production
this means DATA LOSS. Always check for -/+ before applying on databases.

Q6: What are Terraform workspaces?
Workspaces give each environment its own isolated state file while sharing
the same code. Use terraform.workspace in resource names so dev, staging
and prod get uniquely named resources automatically.

Q7: Why should Terraform state never be committed to git?
State files contain sensitive data - resource IDs, ARNs, and sometimes
plaintext secrets. State belongs in S3 with encryption, never in git.

Q8: What is the difference between local and remote state?
Local state lives on your laptop - only you see it, lost if machine dies.
Remote state in S3 is shared by the whole team, has version history, and
DynamoDB locking prevents simultaneous applies.
'@ | Set-Content "D:\cloud-iac\day1-setup\README.md"