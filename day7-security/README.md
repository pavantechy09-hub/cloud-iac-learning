# Day 7 - Security Deep Dive

## Environment
- All AWS labs run on Floci (localhost:4566) - zero cost
- Checkov runs locally - no cloud needed
- Terraform v1.15.5

## Start Every Day
    . D:\cloud-iac\start-env.ps1

---

## What Was Built

### IAM Deep Dive
    iam.tf:
      aws_iam_role prod_readonly_role     - cross-account role with MFA condition
      aws_iam_role_policy prod_readonly   - S3 read + RDS describe only
      aws_iam_policy permission_boundary  - ceiling policy for junior admins

### Transit Gateway (commented - Floci limitation, real AWS code included)
    transit-gateway.tf:
      aws_vpc prod, dev, security         - 3 VPCs representing 3 accounts
      aws_subnet per VPC                  - one subnet each
      aws_ec2_transit_gateway             - commented, not supported in Floci
      aws_ec2_transit_gateway_vpc_attachment x3 - commented, not supported

### Route53 Private Hosted Zone
    route53.tf:
      aws_route53_zone bank.internal      - private DNS zone
      aws_route53_record accounts-db      - CNAME to RDS endpoint, TTL 300
      aws_route53_record accounts-service - A record 10.0.1.10, TTL 60
      aws_route53_record payments-service - A record 10.0.1.11, TTL 60
      aws_route53_record fraud-service    - A record 10.0.1.12, TTL 60

### VPC Flow Logs (commented - Floci limitation, real AWS code included)
    flowlogs.tf:
      aws_s3_bucket bank-vpc-flow-logs    - destination for flow logs
      aws_s3_bucket_lifecycle_configuration - 90 day expiration
      aws_s3_bucket_public_access_block   - blocks all public access
      aws_iam_role vpc-flow-logs-role     - allows flow logs service to write S3
      aws_flow_log                        - commented, not supported in Floci

### Checkov Security Analysis
    Ran against all 7 days of Terraform code
    Initial: 132 passed, 87 failed
    After fixes to Day 6: 33 passed, 17 failed in Day 6 only
    Fixed: storage_encrypted, auto_minor_version_upgrade,
           S3 public access blocks, Secrets Manager recovery window

---

## Core Concepts Learned

### 1. Cross-Account IAM Role
    Problem: dev engineer needs read access to production S3
    Wrong: give them production IAM user credentials (permanent, risky)
    Right: create a role in prod account, dev engineer assumes it temporarily

    How it works:
      Prod account creates role with trust policy:
        Principal = dev account ID (111111111111)
        Condition = MFA must be present
      Dev engineer calls sts:AssumeRole
      Gets back temporary credentials (ASIA prefix, 1 hour expiry)
      Uses them, they auto-expire
      Full audit trail in CloudTrail

    AKIA vs ASIA credentials:
      AKIA = permanent IAM user key (never expires, dangerous if leaked)
      ASIA = temporary assumed role (1 hour, safe, enterprise standard)
      Enterprise rule: AKIA keys should not exist at all

    Proven with real output:
      AccessKeyId: ASIA6Q6E7J6QJ6CONPH0
      Expiration: exactly 1 hour from assumption time
      Session name: pavan-audit-session (appears in CloudTrail)

### 2. Permission Boundary
    Problem: junior admin can create IAM roles but might give them too much access
    Solution: permission boundary = a ceiling that even admins cannot exceed

    How it works:
      Platform team creates boundary policy (what is allowed maximum)
      Junior admin creates a role
      Even if they attach AdministratorAccess to that role
      the boundary limits it to only what the boundary allows
      Prevents privilege escalation completely

    Our boundary allowed: s3 lambda dynamodb logs
    Our boundary denied: iam:CreateUser, organizations:*, account:*
    Result: junior admin cannot create users or touch org settings
            even if they try to give themselves that permission

### 3. Transit Gateway
    Problem: 5 VPCs need to communicate
    Without TGW: N*(N-1)/2 peering connections = 10 for 5 VPCs
                 NOT transitive (A?B?C requires direct A?C peering)
    With TGW: N connections = 5 for 5 VPCs
              FULLY transitive (A can reach C through hub)
              Cross-account supported
              One new VPC = 1 new connection not N new connections

    Key fields:
      amazon_side_asn = 64512           BGP ASN for routing
      auto_accept_shared_attachments    cross-account auto-accept
      default_route_table_association   all attachments auto-routable

    Floci limitation: CreateTransitGateway not supported
    Code is production-ready for real AWS

### 4. Route53 Private Hosted Zone
    Problem: services calling each other by RDS hostname
      accounts-db.c9s3vk2xeq8j.us-east-1.rds.amazonaws.com:5432
      changes if DB recreated, long, fragile

    Solution: private hosted zone bank.internal
      accounts-db.bank.internal ? CNAME to RDS hostname
      accounts-service.bank.internal ? A record to service IP
      Only resolvable INSIDE associated VPCs
      External internet has no idea this zone exists

    Record types:
      CNAME = alias to another hostname (databases - they move rarely)
              TTL 300 - changes propagate within 5 minutes
      A     = direct IP address (services - may move more often)
              TTL 60 - changes propagate within 1 minute

    If RDS recreated:
      Update ONE CNAME record in Route53
      All services automatically use new endpoint
      Zero code changes, zero restarts

    Floci limitation: AssociateVPCWithHostedZone not supported
    Records and zone created correctly, VPC association commented out

### 5. VPC Flow Logs
    Captures every network connection:
      Source IP and port
      Destination IP and port
      Protocol (TCP/UDP)
      Bytes transferred
      ACCEPT or REJECT decision
      Timestamp

    Enterprise uses:
      Security audit: did anything reach our database subnet?
      Forensics: what traffic happened before an incident?
      Compliance: prove security groups are working correctly
      Cost: identify unexpected data transfer

    Two destination options:
      S3 = cheaper for long-term storage, query with Athena
      CloudWatch Logs = real-time alerting and dashboards
      Enterprise: both (CloudWatch for alerts, S3 for archive)

    Floci limitation: CreateFlowLogs not supported
    Code is production-ready for real AWS

### 6. Checkov Static Analysis
    Scans Terraform code BEFORE deployment
    Catches security misconfigurations at code review time
    Blocks insecure code from ever reaching production

    Run command:
      checkov -d D:\cloud-iac --framework terraform --quiet

    Results from our 7 days of code:
      132 passed, 87 failed initially
      After targeted fixes: significant reduction

    How to handle findings:
      Critical (fix immediately):
        storage_encrypted = true on RDS
        block_public_acls on S3 buckets
        deletion_protection = true in prod

      Acceptable with documentation:
        Multi-AZ disabled (Floci limitation)
        Cross-region replication (dev environment)
        Enhanced monitoring (costs extra, dev not needed)

      False positives (skip with comment):
        #checkov:skip=CKV_AWS_157:Multi-AZ disabled for Floci labs
        #checkov:skip=CKV_AWS_293:deletion_protection disabled for lab teardown

    Enterprise CI/CD pattern:
      PR opened ? Checkov runs automatically
      HIGH severity failures ? PR blocked, cannot merge
      MEDIUM findings ? flagged for review, engineer decision
      Accepted findings ? documented with skip comments

### 7. Floci Limitations Summary for Day 7
| Feature | Floci Support | Real AWS |
|---------|--------------|----------|
| IAM roles and policies | Supported | Supported |
| STS AssumeRole | Supported | Supported |
| Route53 zones and records | Supported | Supported |
| Route53 VPC association | NOT supported | Supported |
| Transit Gateway | NOT supported | Supported |
| VPC Flow Logs | NOT supported | Supported |
| S3 public access blocks | Supported | Supported |

---

## Checkov Security Fixes Applied to Day 6

### Fixed
    storage_encrypted = true           RDS data encrypted at rest
    auto_minor_version_upgrade = true  automatic security patches
    aws_s3_bucket_public_access_block  S3 buckets cannot be made public
    recovery_window_in_days = 7        safe secret deletion window

### Accepted with Reason (dev environment)
    Multi-AZ disabled          Floci does not support db_subnet_group
    deletion_protection=false  needed for terraform destroy in labs
    No KMS CMK on secret       KMS CMK setup beyond lab scope
    No cross-region replication DR pattern, not needed for dev
    No S3 access logging       nested logging creates circular dependency

---

## CLI Commands Used
    # IAM and STS
    aws sts assume-role --role-arn arn --role-session-name session
    aws iam list-roles --query "Roles[*].{Name:RoleName,Arn:Arn}" --output table

    # Route53
    aws route53 list-hosted-zones --output table
    aws route53 list-resource-record-sets --hosted-zone-id <id>

    # Checkov
    checkov -d D:\cloud-iac --framework terraform --quiet
    checkov -d D:\cloud-iac\day6-databases --framework terraform --quiet

---

## Interview Questions and Answers

Q1: What is a cross-account IAM role and why use it?
A cross-account role allows an identity in one AWS account to temporarily
assume a role in another account. The target account creates the role with
a trust policy specifying which account or identity can assume it. The
requesting identity calls sts:AssumeRole and receives temporary credentials
valid for up to 1 hour with the ASIA prefix. This eliminates permanent
credential sharing between accounts. The session name appears in CloudTrail
providing a full audit trail of who accessed what and when. We require MFA
as a condition so stolen credentials alone are useless without the second
factor.

Q2: What is a permission boundary in IAM?
A permission boundary is a managed policy that sets the maximum permissions
an IAM role or user can have. Even if an admin attaches AdministratorAccess
to a role, if a boundary policy is also attached that only allows S3 and
Lambda, the effective permissions are only S3 and Lambda. This prevents
privilege escalation where a junior admin creates a role with more access
than they should be able to grant. The boundary defines the ceiling and
cannot be exceeded regardless of what policies are directly attached.

Q3: What is AWS Transit Gateway and when do you need it?
Transit Gateway is a central hub that connects multiple VPCs and on-premises
networks. Without it, connecting N VPCs requires N*(N-1)/2 peering
connections which are not transitive. With Transit Gateway each VPC connects
once to the hub and can reach all other connected VPCs transitively. It also
supports cross-account connections. For a bank with separate prod, dev, and
security accounts, one Transit Gateway connects all three with three
connections instead of three non-transitive peering connections.

Q4: What is a Route53 private hosted zone?
A private hosted zone creates DNS records only resolvable inside associated
VPCs. Services call each other by stable names like accounts-db.bank.internal
instead of long auto-generated AWS hostnames that change when resources are
recreated. When an RDS instance is replaced, you update one CNAME record and
all services automatically use the new endpoint with zero code changes. The
zone is invisible to the public internet. TTL values control how quickly
changes propagate - low TTL for services that may move, higher for databases
that rarely change.

Q5: What do VPC Flow Logs capture and why are they important?
Flow logs record metadata about every network connection in a VPC - source
and destination IP and port, protocol, bytes transferred, and whether the
connection was accepted or rejected by security groups and NACLs. They do
not capture packet contents. They are critical for security auditing to prove
security groups are correctly blocking unauthorized access, forensic
investigation after incidents to understand what traffic occurred before and
during an attack, and compliance requirements that mandate network traffic
logging. They can be sent to S3 for long-term archival queried with Athena
or to CloudWatch Logs for real-time alerting.

Q6: How do you use Checkov in an enterprise CI/CD pipeline?
Checkov is added as a step in the pull request pipeline before any Terraform
plan or apply. It scans all .tf files and reports findings categorized by
severity. High severity failures block the PR from merging - no insecure
code reaches production. Medium findings are flagged for engineer review.
When a finding is intentionally accepted, a skip comment is added directly
in the Terraform code with the reason documented. This creates an auditable
record of every security decision. The key discipline is triaging findings -
distinguishing genuinely critical issues from findings that are low risk in
context or represent acceptable tradeoffs for the environment.

Q7: What is the difference between AKIA and ASIA credentials in AWS?
AKIA prefix indicates permanent IAM user access keys that never expire unless
explicitly deleted or rotated. They are high risk because if leaked they
provide indefinite access. ASIA prefix indicates temporary credentials issued
by STS for assumed roles, valid for at most 12 hours and typically 1 hour.
Enterprise security policy should eliminate all AKIA keys and require
everyone to use role assumption instead. Temporary credentials with short
expiry windows dramatically reduce the blast radius of credential compromise.