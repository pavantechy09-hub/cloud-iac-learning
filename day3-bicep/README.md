# Day 3 - Bicep + ARM Templates

## Environment Setup
- floci-az running on localhost:4577 (Azure emulator)
- Bicep CLI 0.44.1
- Azure CLI installed
- floci-az supports: Blob, Queue, Table, Service Bus, Event Hubs
- floci-az does NOT support: ARM deployments, VNet, Key Vault via CLI

## Start Environment Every Day
    . D:\cloud-iac\start-env.ps1
    floci az start

---

## What Was Built

### Bicep Files Written from Scratch
    storage.bicep    - Storage Account with outputs
    vnet.bicep       - VNet + 3 subnets + 3 NSGs
    keyvault.bicep   - Key Vault + secrets
    servicebus.bicep - Service Bus + queue + topic

### Module Structure
    modules/
      vnet/
        vnet.bicep   - reusable VNet + NSG module
    envs/
      dev/
        main.bicep   - calls module with dev values (10.0.0.0/16)
        parameters.json - dev parameter values
      staging/
        main.bicep   - calls module with staging values (10.1.0.0/16)

### Hands-on with floci-az
    Created containers: payments, logs, configs, bicep-demo
    Uploaded app-config.json to configs container
    Downloaded and verified content
    Listed blobs with metadata

---

## Core Concepts Learned

### 1. What is ARM and why it exists
    ARM = Azure Resource Manager
    Every Azure operation goes through ARM
    Portal clicks, CLI commands, Bicep, Terraform = all go through ARM
    ARM uses JSON templates to describe infrastructure
    ARM is the engine, Bicep is the cleaner language on top

### 2. Bicep vs ARM vs Terraform
    Bicep
      Azure only
      Compiles to ARM JSON
      Clean readable syntax
      Microsoft officially supported
      Best for Azure-only teams

    ARM JSON
      Azure only
      Verbose but most powerful
      Some features only in raw ARM
      Required knowledge for interviews
      What Azure actually executes

    Terraform
      Multi-cloud AWS Azure GCP
      One tool for everything
      Slightly behind Azure-native features
      Industry standard for DevOps roles

### 3. Bicep Syntax Rules
    param = input variable
      param environment string = 'dev'

    resource declaration:
      resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {

    string interpolation:
      '${environment}-vnet'   Bicep
      "[format('{0}-vnet', parameters('environment'))]"   ARM equivalent

    parent-child relationship:
      resource secret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
        parent: keyVault
        ...
      }

    output:
      output vnetId string = vnet.id

### 4. ARM Template 6 Sections
    $schema          tells Azure which ARM schema version
    contentVersion   always 1.0.0.0
    metadata         generator info (bicep version etc)
    parameters       inputs same as Bicep params
    resources        what gets deployed
    outputs          what comes back after deploy

### 5. Bicep Modules vs Terraform Modules
    Both follow same pattern:
      source/path = where module lives
      inputs      = what you pass in
      outputs     = what you get back

    Bicep module call:
      module vnet '../../modules/vnet/vnet.bicep' = {
        name: 'vnet-deployment'
        params: {
          environment: environment
        }
      }

    Terraform module call:
      module "vpc" {
        source      = "../../modules/vpc"
        environment = "dev"
      }

    Key difference:
      Bicep modules are compile-time only
      ARM flattens everything into one JSON file
      Terraform modules exist at runtime in state file

### 6. NSG vs AWS Security Group
    AWS Security Group
      Allow rules only
      Everything else implicitly denied
      Cannot explicitly block specific IP
      Attached to resources (EC2, RDS)
      Stateful

    Azure NSG
      Allow AND Deny rules
      Can explicitly block specific attacker IP
      Priority number decides evaluation order
      Lower number = evaluated first
      Attached to subnet OR NIC
      Stateful

    Priority system:
      100 evaluated first
      200 evaluated second
      Use gaps 100 200 300 not 100 101 102
      Two rules cannot share same priority
      Azure rejects deployment if duplicate priority

### 7. NSG Attachment - Subnet vs NIC
    Subnet level NSG
      Applies to ALL resources in subnet
      Simpler for tier-based security
      One NSG covers all VMs in private subnet

    NIC level NSG
      Applies to ONE specific VM
      Used when individual VMs need different rules
      Traffic must pass BOTH subnet and NIC NSG
      Double security layer

### 8. what-if vs terraform plan
    terraform plan -out=tfplan              Bicep what-if
    shows + create - destroy ~ modify       shows + Create - Delete ~ Modify
    needs no login                          needs az login to real Azure
    saves plan file                         no save to file

### 9. Parameters file vs tfvars
    Terraform tfvars:                       Bicep parameters.json:
    environment = "dev"                     { "parameters": {
    vpc_cidr = "10.0.0.0/16"                 "environment": { "value": "dev" }
                                            }}
    Both pass environment-specific values
    without changing the template

### 10. Azure Blob Storage vs AWS S3
    Azure                                   AWS
    Storage Account                         S3 bucket (partial equivalent)
    Container                               S3 bucket
    Blob                                    S3 object
    Connection string auth                  Access key + secret auth
    az storage blob upload                  aws s3 cp

---

## CLI Commands Used
    # Containers
    az storage container create --name payments --connection-string $conn
    az storage container list --connection-string $conn --output table

    # Blobs
    az storage blob upload --container-name configs --name file.json --file file.json --connection-string $conn
    az storage blob download --container-name configs --name file.json --file out.json --connection-string $conn
    az storage blob list --container-name configs --connection-string $conn --output table

    # Bicep
    az bicep build --file main.bicep        compile to ARM JSON
    az bicep decompile --file main.json     convert ARM back to Bicep

---

## Issues Faced and Fixes
| Issue | Cause | Fix |
|-------|-------|-----|
| BCP018 error on bicep build | Wrong quote style in resource type | Ensure API version inside single quotes |
| az login required for what-if | floci-az does not support ARM deployments | Use real Azure account for full deployment |
| curl resource not found | floci-az has no _floci/services endpoint | Check floci.io docs for supported services |
| management-group-id unrecognized | Wrong flag for deployment group | Remove flag, only use resource-group |

---

## Interview Questions and Answers

Q1: What is the difference between Bicep and ARM?
Bicep is a domain-specific language that compiles to ARM JSON. You write
clean readable Bicep and Azure converts it to verbose ARM JSON before
deploying. ARM is what Azure actually executes. Bicep is 60% less code
for the same result, supports modules, and has better IDE tooling.
Think of it like TypeScript compiling to JavaScript.

Q2: What are the 6 sections of an ARM template?
Schema defines the ARM template schema version. ContentVersion is always
1.0.0.0 for human versioning. Metadata contains generator info. Parameters
are inputs equivalent to Bicep params. Resources is the array of what gets
deployed. Outputs is what comes back after deployment like resource IDs.

Q3: How does NSG priority work in Azure?
Each NSG rule has a unique priority from 100 to 4096. Lower number means
higher priority and gets evaluated first. When a rule matches Azure stops
evaluating and applies that rule. Two rules cannot share the same priority
and Azure rejects the deployment. Enterprise teams use gaps like 100 200 300
so new rules can be inserted without renumbering existing ones.

Q4: What is the difference between attaching NSG to subnet vs NIC?
Subnet-level NSG applies to all resources in that subnet - simpler for
tier-based security. NIC-level NSG applies to one specific VM for granular
per-resource control. Both can be used together and traffic must pass both
NSGs creating a double security layer. AWS Security Groups are always
resource-level, Azure NSGs offer both options.

Q5: Why can Azure NSG block specific IPs but AWS Security Group cannot?
AWS Security Groups only support allow rules with implicit deny for everything
else. You cannot write an explicit deny rule. Azure NSGs support both allow
and deny rules so you can explicitly block a known malicious IP address with
a deny rule at priority 50 while still allowing legitimate traffic at priority
100. This is critical for enterprises that need to respond quickly to attacks.

Q6: How do Bicep modules work compared to Terraform modules?
Both follow the same pattern of inputs logic and outputs like a function.
The key difference is that Bicep modules only exist at compile time. When
you run az bicep build the compiler inlines all module code into one flat
ARM JSON file. Terraform modules exist at runtime and are tracked separately
in the state file. Both prevent code duplication and allow one change to
propagate to all environments.

Q7: What is the what-if command in Bicep?
what-if is the Azure equivalent of terraform plan. It shows what changes
would be made without actually deploying. It uses plus for create, minus
for delete, tilde for modify. Unlike terraform plan it requires az login to
real Azure because it must query actual resource state. Run with:
az deployment group what-if --resource-group rg-dev --template-file main.bicep

Q8: What is the difference between Azure Blob Storage and AWS S3?
Both are object storage services. S3 has buckets containing objects. Azure
has Storage Accounts containing Containers which contain Blobs. The hierarchy
has one extra level in Azure. Authentication differs - S3 uses access key
and secret while Azure uses a connection string that combines account name
key and endpoints. Functionality is equivalent for most enterprise use cases.

Q9: What Bicep functions are equivalent to ARM template functions?
Bicep uses plain variable references like storageAccount.id while ARM uses
resourceId() function. Bicep uses string interpolation like environment-vnet
while ARM uses format() or concat() functions. Bicep uses subscription().tenantId
while ARM uses subscription().tenantId in bracket syntax. Bicep hides the
verbose function syntax but compiles to identical ARM output.

Q10: How do you pass secrets in Bicep without hardcoding them?
Use Key Vault references in your parameters file. Instead of a plain value
set the reference property pointing to the Key Vault secret URI. Azure
resolves the secret at deploy time and injects it without it appearing in
your code or state. Combined with enableRbacAuthorization on the Key Vault
and Managed Identity on the deploying service you get zero hardcoded secrets
in the entire deployment pipeline.