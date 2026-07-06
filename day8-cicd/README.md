# Day 8 - CI/CD Pipelines

## What Was Built
    .github/workflows/terraform.yml      GitHub Actions for Terraform
    .github/workflows/drift-detection.yml Scheduled drift detection
    day8-cicd/azure-pipelines.yml        Azure DevOps for Bicep

---

## Why CI/CD Matters

Without CI/CD:
  Engineers apply Terraform from laptops
  No review of what changes before apply
  No audit trail of who changed what
  Credentials on every laptop
  State file conflicts between engineers
  Manual process = human error

With CI/CD:
  Every change goes through a PR
  Plan posted automatically for review
  Apply only after approval and merge
  Credentials never on any laptop (OIDC)
  Full audit trail in GitHub
  Checkov blocks insecure code automatically

---

## GitHub Actions Terraform Pipeline

### Trigger
    on pull_request ? runs plan only, never apply
    on push to main ? runs apply (after PR merged and approved)
    paths filter ? only triggers when Terraform files change
                   README change does not trigger infrastructure deployment

### Jobs and Order
    Job 1: security-scan (always runs first)
      checkov scans all .tf files
      soft_fail = true for learning, false in strict enterprise
      blocks subsequent jobs if HIGH findings in strict mode

    Job 2: terraform-plan (PR only)
      terraform fmt -check     verify formatting
      terraform init           download providers
      terraform validate       syntax and logic check
      terraform plan           shows what will change
      posts plan as PR comment so reviewers see exact changes

    Job 3: terraform-apply (merge to main only)
      only runs after PR approved and merged
      terraform apply -auto-approve
      applies exactly what was reviewed in plan

### OIDC vs Static Credentials
    Wrong approach:
      AWS_ACCESS_KEY_ID stored in GitHub Secrets
      Permanent, never expires, dangerous if GitHub breached

    Right approach (what we wrote):
      role-to-assume: secrets.AWS_ROLE_ARN
      GitHub requests short-lived token from AWS at runtime
      AWS verifies the request is genuinely from your repo
      Token valid for 15 minutes only
      Nothing to steal if GitHub is compromised

    AWS side requires:
      IAM role with trust policy allowing GitHub OIDC provider
      Condition: repo must match your specific repo name
      Prevents other repos from assuming your role

### PR Comment Format
    Pipeline posts to every PR:
      Format check result
      Validate result
      Plan result
      Full plan output in collapsible section
      Who triggered the run
    Team reviews plan before approving PR
    No surprises in production

---

## Azure DevOps Pipeline for Bicep

### Stages
    Stage 1: Validate (always runs)
      az bicep install
      az bicep build all .bicep files
      az deployment group what-if on PR only
        shows what Azure would create/modify/delete
        equivalent of terraform plan for Azure

    Stage 2: Deploy (main branch only, after Validate succeeds)
      az deployment group create
      deploys to Azure resource group
      build ID in deployment name for traceability

### Service Connection vs Static Credentials
    Azure DevOps uses Service Connection
    Configured with federated identity (same concept as OIDC)
    No client secret stored
    Short-lived tokens only
    Configured in Azure DevOps project settings

---

## Drift Detection Workflow

### Schedule
    cron: 0 6 * * 1-5
    Runs at 6am every Monday through Friday
    Before engineers start work
    Also triggerable manually via workflow_dispatch

### How It Works
    terraform plan -detailed-exitcode
      Exit 0 = no changes (infrastructure matches code)
      Exit 1 = error in plan
      Exit 2 = changes detected = DRIFT

    If exit code 2:
      Creates a GitHub Issue automatically
      Title: "Infrastructure Drift Detected - 2026-07-01"
      Body: full terraform plan output showing what drifted
      Labels: infrastructure, drift, security
      Team gets email notification
      Security investigates what changed outside IaC

### Why Drift Detection Matters
    Someone makes a manual change in AWS console at 11pm
    Drift detection runs at 6am
    Team knows before making their own changes that morning
    Prevents: "why did terraform plan want to delete this resource?"
    Prevents: security rules being changed manually and forgotten
    Enforces: IaC is always the source of truth

---

## The Full PR Workflow (Real Team)

    1. Engineer branches: git checkout -b feature/rds-encryption
    2. Makes change to main.tf: storage_encrypted = true
    3. Opens Pull Request on GitHub
    4. GitHub Actions triggers automatically:
         Checkov scan ? posts security results
         terraform plan ? posts plan to PR comment
         Plan shows: aws_db_instance will be updated
                     storage_encrypted: false ? true
    5. Senior engineer reviews PR + plan comment
    6. Approves the PR
    7. Engineer merges
    8. GitHub Actions triggers terraform-apply
    9. Change deployed automatically
    10. Audit trail: who changed what, when, PR link, plan output

---

## Key Concepts

### Why paths filter matters
    Without paths filter:
      Every commit triggers terraform plan and apply
      Someone fixes a typo in README ? triggers RDS modification
      Slow, expensive, confusing
    With paths filter:
      Only changes to day2-networking/** trigger VPC workflows
      Only changes to day6-databases/** trigger RDS workflows
      Right workflow for right changes

### terraform plan -detailed-exitcode
    Exit code 0 = no changes needed (used in drift detection)
    Exit code 1 = error (something went wrong)
    Exit code 2 = changes detected (used to trigger drift alerts)
    Standard exit codes allow scripts to take different actions

### Environment protection rules
    In real enterprise: github environment named "production"
    Requires specific reviewers to approve before apply runs
    Even after PR merged, apply waits for production approval
    Extra gate for production vs dev/staging

---

## Interview Questions and Answers

Q1: What is the difference between CI and CD in infrastructure?
CI (Continuous Integration) validates that code changes are correct -
it runs checkov, terraform validate, terraform plan, and posts results
for review. CD (Continuous Delivery or Deployment) applies the validated
changes - terraform apply runs after a PR is approved and merged. The key
is that CI runs on every PR while CD only runs on merge to main, ensuring
nothing reaches production without review.

Q2: Why use OIDC instead of storing AWS credentials in GitHub Secrets?
Stored credentials are permanent and become a liability if the secret
store is compromised. OIDC (OpenID Connect) allows GitHub Actions to
request short-lived temporary credentials from AWS at runtime by proving
its identity cryptographically. AWS validates the request is genuinely
from your specific repository and issues credentials valid for 15 minutes.
There are no long-lived secrets to steal - even a full compromise of your
GitHub repository yields no usable AWS credentials.

Q3: What does terraform plan -detailed-exitcode do and why is it used?
The -detailed-exitcode flag makes terraform plan return exit code 2 when
it detects changes, instead of the normal exit code 0 for success. This
allows CI/CD pipelines and drift detection scripts to distinguish between
"plan succeeded with no changes" (exit 0) and "plan succeeded but found
differences" (exit 2). We use this in the drift detection workflow to
trigger a GitHub Issue only when actual infrastructure drift is found.

Q4: How do you prevent a PR from accidentally deploying infrastructure?
The pipeline uses separate jobs with different conditions. The plan job
has condition if github.event_name == pull_request so it only runs on
PRs and never applies changes. The apply job has condition if github.ref
== refs/heads/main and github.event_name == push so it only runs after
code is merged. The paths filter ensures only Terraform file changes
trigger the pipeline. Branch protection rules prevent direct pushes to
main so every change must go through a PR.

Q5: What is drift detection and how do you implement it?
Drift occurs when real infrastructure no longer matches the Terraform
state and code - typically from manual console changes. We implement
drift detection as a scheduled GitHub Actions workflow running at 6am
every weekday. It runs terraform plan with -detailed-exitcode. Exit code
2 means drift was detected and the workflow automatically creates a GitHub
Issue with the full plan output showing what changed. The team is notified
before starting work and can investigate the manual change before it
causes conflicts.

Q6: What is the role of Checkov in a CI/CD pipeline?
Checkov is the security gate that runs before any Terraform plan or apply.
It scans all Terraform code for security misconfigurations - missing
encryption, public access blocks, deletion protection, logging settings.
In strict enterprise mode soft_fail is false so any HIGH severity finding
blocks the entire pipeline and prevents the PR from being merged. This
ensures no insecure infrastructure ever reaches production regardless of
who wrote it. Engineers fix security issues during code review, not after
production deployment.