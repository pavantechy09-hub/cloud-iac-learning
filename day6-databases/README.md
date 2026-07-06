# Day 6 - Databases + Storage

## Environment
- All AWS labs run on Floci (localhost:4566) - zero cost
- Azure labs written in Bicep, compiled to ARM - same pattern as Day 3
- Terraform v1.15.5, Bicep CLI 0.44.1

## Start Every Day
    . D:\cloud-iac\start-env.ps1

---

## What Was Built

### AWS (Terraform + Floci)
    RDS PostgreSQL 15.4     - accounts-db, db.t3.micro, 20GB
    Security Group          - port 5432 from app subnet only (10.0.2.0/24)
    Secrets Manager         - full connection JSON at bank/accounts-db/password
    S3 bucket               - bank-transaction-archive with versioning
    S3 lifecycle policy     - 90d STANDARD_IA, 365d GLACIER, 2555d delete

### Azure (Bicep - compiled only)
    cosmosdb.bicep          - CosmosDB account + database + container
    azuresql.bicep          - Azure SQL server + database, @secure() param pattern

---

## Core Concepts Learned

### 1. RDS vs Self-Managed PostgreSQL
    Self-managed on EC2:
      YOU patch OS and Postgres engine
      YOU configure and test backups
      YOU handle failover when instance dies
      YOU monitor disk, replication lag, connections
      3am pages = your problem

    RDS managed:
      AWS patches OS and engine (you choose WHEN)
      Automated daily backups + point-in-time recovery built in
      Multi-AZ failover automatic (60-120 seconds)
      CloudWatch metrics built in
      You write Terraform, AWS runs infrastructure

### 2. RDS Key Parameters You Must Know
    db_subnet_group        which subnets RDS can live in (requires 2 AZs for Multi-AZ)
    multi_az = true        standby replica in second AZ, auto-promotes on failure
    backup_retention_period = 7    keeps 7 days of automated backups
    deletion_protection = true     prevents accidental terraform destroy (use in prod)
    skip_final_snapshot = false    takes a final backup before deletion (use in prod)
    allocated_storage      GB of storage provisioned
    engine_version         pin this explicitly, never let it auto-upgrade in prod

### 3. Secrets Manager - The Right Pattern
    WRONG - hardcoded in Terraform:
      password = "TempPassword123!"
      stored in main.tf + terraform.tfstate in plain text

    RIGHT - Secrets Manager:
      Step 1: bootstrap secret with Terraform (one time)
      Step 2: rotate immediately via AWS rotation Lambda
      Step 3: app reads at runtime via SDK - zero hardcoded credentials

    Secret stored as JSON with ALL connection details:
      {"host":"...","port":5432,"username":"...","password":"...","dbname":"..."}
    App reads ONE secret, gets everything needed to connect.

    IAM permission needed: secretsmanager:GetSecretValue on specific secret ARN
    Lambda execution role from Day 4 would add this to its least-privilege policy

    Terraform enterprise pattern:
      resource "random_password" "db" { length = 32 }
      password = random_password.db.result
      Never typed by human, never seen by human

### 4. S3 Lifecycle - Cost Control + Compliance
    Storage classes (cheapest to most expensive per GB/month):
      GLACIER          $0.004/GB  - archive, retrieval minutes-hours
      STANDARD_IA      $0.0125/GB - infrequent access, millisecond retrieval
      STANDARD         $0.023/GB  - default, immediate retrieval

    Bank regulatory requirement (7 years retention):
      Day 0-90:    STANDARD         active queries, fast retrieval needed
      Day 90-365:  STANDARD_IA      rarely queried, 60% cheaper
      Day 365-2555: GLACIER         compliance archive only, 83% cheaper
      Day 2555:    deleted          7 years satisfied, automatic cleanup

    filter {} = apply rule to ALL objects in bucket
    Without filter: Terraform warning + future error

### 5. S3 Versioning
    Versioning enabled = every object overwrite creates a new version
    Previous versions retained, never lost on accidental overwrite
    Prerequisite for most lifecycle policies
    Required for S3 as Terraform remote state backend (Day 1)

### 6. CosmosDB Consistency Levels (MOST ASKED Azure interview topic)
    5 levels from weakest to strongest:

    Eventual         fastest reads, may be stale - social media, leaderboards
    Consistent Prefix reads in order, may lag - event logs
    Session          YOUR writes immediately visible to YOU - 95% of web apps
    Bounded Staleness all users within N seconds of latest - near real-time
    Strong           all users see exact same data - financial ledger, inventory

    We chose Session for fraud-events container:
      fraud analyst writes a fraud alert
      they immediately see their own write
      other analysts may see it slightly later - acceptable
      much cheaper than Strong (half the RU/s cost)

    Strong consistency cost:
      every read waits for ALL global replicas to confirm the write
      adds 100-300ms per write if CosmosDB has multiple regions
      costs 2x Request Units vs Session

### 7. CosmosDB Structure
    Account (databaseAccounts)
      Database (sqlDatabases)
        Container (containers)
          Items (documents/rows)

    Partition key = how data is distributed across physical partitions
      /accountId = all fraud events for one account stored together
      good partition key = even distribution + query pattern match
      bad partition key = "hot partition" (one account gets all traffic)

### 8. Azure SQL @secure() Parameter Pattern
    WRONG - getSecret() directly on resource property:
      administratorLoginPassword: keyVault.getSecret('sql-admin-password')
      Bicep compiler error BCP180 - not allowed on resource properties

    CORRECT - @secure() parameter:
      @secure()
      param sqlAdminPassword string
      administratorLoginPassword: sqlAdminPassword

      Caller passes the secret at deploy time:
        --parameters sqlAdminPassword="$(az keyvault secret show ...)"

    @secure() decorator ensures:
      value never appears in deployment logs
      never stored in deployment history
      never shown in ARM output
      treated as sensitive end-to-end

### 9. Azure SQL Security Settings
    publicNetworkAccess: 'Disabled'
      SQL server not reachable from internet at all
      only via Private Endpoint from within VNet
      mirrors data subnet isolation from Day 2

    minimalTlsVersion: '1.2'
      rejects TLS 1.0/1.1 connections
      PCI-DSS and enterprise security mandate this

### 10. Floci Limitations Found in Day 6
| Feature | Floci Support | Real AWS |
|---------|--------------|----------|
| RDS PostgreSQL basic | Supported | Supported |
| db_subnet_group | NOT supported | Supported |
| Multi-AZ RDS | NOT supported (needs subnet group) | Supported |
| RDS tagging (AddTagsToResource) | NOT supported | Supported |
| Secrets Manager | Supported | Supported |
| S3 lifecycle policies | Supported | Supported |

---

## CLI Commands Used
    # RDS
    aws rds describe-db-instances --db-instance-identifier accounts-db --output table
    aws rds describe-db-instances --query "DBInstances[0].{Status:...,Engine:...}" --output table

    # Secrets Manager
    aws secretsmanager get-secret-value --secret-id "bank/accounts-db/password" --query "SecretString" --output text

    # S3 Lifecycle
    aws s3api get-bucket-lifecycle-configuration --bucket bank-transaction-archive

    # Bicep
    az bicep build --file cosmosdb.bicep
    az bicep build --file azuresql.bicep

---

## Issues Faced and Fixes
| Issue | Cause | Fix |
|-------|-------|-----|
| CreateDBSubnetGroup not supported | Floci limitation | Removed subnet group, used default networking |
| AddTagsToResource not supported | Floci limitation | Removed tags from aws_db_instance |
| S3 lifecycle warning - no filter | Missing filter block | Added filter {} inside rule block |
| BCP180 getSecret() error | getSecret() only valid as module param | Used @secure() param pattern instead |

---

## Interview Questions and Answers

Q1: Why use RDS instead of running PostgreSQL on EC2?
RDS eliminates the undifferentiated heavy lifting of database operations.
AWS handles OS patching, engine patching, automated backups with
point-in-time recovery, Multi-AZ failover, and CloudWatch metrics. For
a bank running PostgreSQL on EC2 means a DBA team on call 24/7 for
things AWS automates. The tradeoff is less control over exact
configuration but that is almost always worth it for operational teams.

Q2: What is RDS Multi-AZ and how does failover work?
Multi-AZ keeps a synchronous standby replica in a second Availability
Zone. All writes to the primary are synchronously replicated before
acknowledging to the application. If the primary fails, RDS automatically
promotes the standby — the DNS endpoint stays the same so applications
reconnect without configuration changes. Failover typically takes 60 to
120 seconds. This is not a read scaling solution — the standby is not
readable. For read scaling you use Read Replicas.

Q3: How do you securely pass a database password in Terraform?
Never hardcode it. The enterprise pattern uses the random_password
resource to generate a cryptographically random password that no human
ever sees. Store it in Secrets Manager alongside the full connection
details as a JSON object. The application reads the secret at runtime
via SDK using the Lambda execution role permission
secretsmanager:GetSecretValue on that specific secret ARN. Rotate via
the AWS-managed rotation Lambda on a schedule. The password never
appears in code, git history, or state files.

Q4: What is the difference between S3 storage classes?
Standard is the default — immediate retrieval, highest cost at around
$0.023 per GB per month. Standard-IA (Infrequent Access) is 60% cheaper
for data queried less than once a month with millisecond retrieval.
Glacier is 83% cheaper for archival data where retrieval taking minutes
to hours is acceptable. For bank transaction records, lifecycle policies
automate the tiering — active transactions in Standard, transactions over
90 days in IA, over 1 year in Glacier, deleted after 7 years to satisfy
regulatory requirements automatically.

Q5: What are CosmosDB consistency levels and when do you use each?
CosmosDB offers five levels. Eventual is fastest but reads may be stale,
suitable for non-critical data like leaderboards. Session guarantees your
own writes are immediately visible to you but not necessarily to others,
suitable for 95% of user-facing scenarios. Strong guarantees all users
see the same data at all times but doubles cost and adds 100 to 300ms
latency for global replicas. For a bank we used Session for fraud events
because analysts see their own writes immediately and slight lag for
others is acceptable, saving significant cost over Strong consistency.

Q6: What is the @secure() decorator in Bicep and why use it?
The @secure() decorator marks a parameter as sensitive. Bicep prevents
the value from appearing in deployment logs, deployment history, or ARM
outputs. It also prevents direct assignment to resource properties from
Key Vault via getSecret() — that only works for module parameters,
enforcing the pattern where secrets flow through module boundaries rather
than being embedded in resource definitions. The correct pattern is to
pass the secret from the CI/CD pipeline at deploy time using the
az keyvault secret show command, keeping credentials out of all YAML
and Bicep files entirely.