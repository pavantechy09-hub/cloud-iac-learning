# Day 2 - VPC Networking with Terraform

## Environment Setup
- Floci running on localhost:4566
- Terraform v1.15.5
- AWS CLI with dummy credentials (test/test)
- All resources deployed to Floci locally

## Start Environment Every Day
    . D:\cloud-iac\start-env.ps1

---

## What Was Built
Full 3-tier AWS VPC architecture as a reusable Terraform module.
Deployed to dev (10.0.0.0/16) and staging (10.1.0.0/16) from same module.

## Folder Structure
    day2-networking/
      modules/
        vpc/
          main.tf       - VPC, subnets, IGW, EIP, route tables, security groups
          variables.tf  - inputs: environment, vpc_cidr, subnet cidrs, az
          outputs.tf    - outputs: vpc_id, subnet_ids, sg_ids
      envs/
        dev/            - calls module with 10.0.0.0/16
        staging/        - calls module with 10.1.0.0/16

---

## Architecture Built

    Internet
      down
    Internet Gateway (front door - two way)
      down
    Public Subnet 10.x.1.0/24
      ALB - receives all internet traffic
      NAT Gateway - lets private subnet reach internet outbound only
      down
    Private Subnet 10.x.2.0/24
      App servers - no public IP, only reachable from ALB security group
      down
    Data Subnet 10.x.3.0/24
      Databases - zero internet route, only reachable from app-sg

---

## Concepts Learned

### 1. VPC and CIDR
    VPC = your private isolated network in AWS
    CIDR 10.0.0.0/16 = 65,536 IP addresses (10.0.0.0 to 10.0.255.255)

    /16 = 65,536 addresses - entire VPC
    /24 = 256 addresses    - one subnet
    /32 = 1 address        - single IP
    Rule: bigger number after / means smaller range

### 2. Three Subnet Tiers
    Public subnet
      map_public_ip_on_launch = true
      route table: 0.0.0.0/0 to IGW
      resources: ALB, NAT Gateway

    Private subnet
      no public IP
      route table: 0.0.0.0/0 to NAT Gateway
      resources: app servers, ECS tasks

    Data subnet
      no public IP
      NO internet route at all
      resources: RDS, ElastiCache, databases

### 3. Internet Gateway vs NAT Gateway
    Internet Gateway
      two-way door
      internet can reach you AND you can reach internet
      attached to VPC not subnet
      free to create
      used by PUBLIC subnet

    NAT Gateway
      one-way exit
      you can reach internet but internet cannot reach you
      lives in PUBLIC subnet
      used by PRIVATE subnet via route table
      costs $0.045 per hour plus $0.045 per GB
      needs Elastic IP (static public IP)
      one per AZ for high availability

### 4. Route Tables
    public-rt:   10.0.0.0/16 to local, 0.0.0.0/0 to IGW
    private-rt:  10.0.0.0/16 to local, 0.0.0.0/0 to NAT
    data-rt:     10.0.0.0/16 to local only (no internet)

    Route table without association = useless
    Association without route table = useless
    Both together = traffic knows where to go

### 5. Security Groups - 3-Tier Model
    alb-sg
      ingress port 80  from 0.0.0.0/0 (internet)
      ingress port 443 from 0.0.0.0/0 (internet)
      egress  all      to   0.0.0.0/0

    app-sg
      ingress port 8080 from security_groups=[alb-sg] NOT cidr
      egress  all       to   0.0.0.0/0

    db-sg
      ingress port 5432 from security_groups=[app-sg] NOT cidr
      NO egress (databases initiate nothing outbound)

    Why security_groups NOT cidr_blocks:
      cidr_blocks = any IP in that range can connect
      security_groups = only members of that group can connect
      when ALB scales from 2 to 20 instances the rule still works
      no manual updates ever needed

### 6. Security Group vs NACL
    Security Group
      stateful - return traffic automatically allowed
      attached to resources (EC2, RDS, ALB)
      allow rules only, no deny
      evaluated all at once

    NACL
      stateless - must explicitly allow return traffic both ways
      attached to subnets
      has both allow and deny rules
      evaluated in order by rule number
      use for broad subnet-level blocks

### 7. ALB vs NLB
    ALB = Application Load Balancer
      Layer 7 - reads HTTP content
      routes by URL path, headers, hostname
      use for web apps, REST APIs, microservices
      standard choice for 99% of web applications

    NLB = Network Load Balancer
      Layer 4 - raw TCP/UDP packets
      extreme speed, millions of connections
      use for gaming, IoT, real-time systems
      does not understand HTTP

### 8. Terraform Modules
    Problem: copy-paste VPC code per environment = drift risk
    Solution: write once in modules/vpc, call from each env

    Module has 3 parts:
      variables.tf = inputs  (what you pass in)
      main.tf      = logic   (what gets built)
      outputs.tf   = outputs (what comes back)

    Caller in envs/dev/main.tf:
      module "vpc" {
        source      = "../../modules/vpc"
        environment = "dev"
        vpc_cidr    = "10.0.0.0/16"
      }

    One security fix in modules/vpc = all environments updated

---

## CLI Audit Commands Used
    aws ec2 describe-vpcs --query "Vpcs[*].{ID:VpcId,CIDR:CidrBlock}" --output table
    aws ec2 describe-subnets --query "Subnets[*].{ID:SubnetId,CIDR:CidrBlock,Public:MapPublicIpOnLaunch}" --output table
    aws ec2 describe-security-groups --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" --output table
    aws ec2 describe-route-tables --query "RouteTables[*].{ID:RouteTableId,Routes:Routes}" --output table

---

## Issues Faced and Fixes
| Issue | Cause | Fix |
|-------|-------|-----|
| NAT Gateway unsupported | Floci limitation | Remove from Floci, code correct for real AWS |
| mkdir created folder not file | Wrong command used | Use Set-Content to create files |
| Terraform PATH lost | New terminal session | Run start-env.ps1 or set PATH manually |
| output.tf vs outputs.tf | Naming inconsistency | Rename-Item with full path |
| Auth failure on AWS CLI | Credentials reset | Set AWS env vars again |
| Access denied on Set-Content | main.tf was a folder | Remove-Item then recreate as file |

---

## Interview Questions and Answers

Q1: What is a VPC and why do we need one?
A VPC is a logically isolated private network in AWS where you control
the IP address range, subnets, routing, and security. Without a VPC your
resources share network space with other customers. VPC gives full control
over network topology and is required before deploying any AWS resource.

Q2: What is the difference between public and private subnet?
Public subnet has a route to Internet Gateway so resources can receive
internet traffic and can have public IPs. Private subnet has no IGW route
so resources are unreachable from internet and have private IPs only.
Private subnet can still reach internet outbound via NAT Gateway.

Q3: What is the difference between Internet Gateway and NAT Gateway?
IGW is bidirectional - internet can reach your resources and vice versa.
NAT is unidirectional - your private resources can reach internet for
updates and API calls but nobody from internet can initiate a connection in.
IGW is free. NAT costs $0.045 per hour. IGW attaches to VPC.
NAT lives in public subnet and is used by private subnet route table.

Q4: Why put databases in a separate data subnet?
Defense in depth. Private subnet may need NAT for outbound internet.
Data subnet has zero internet route - not even outbound. Even if private
subnet is compromised the attacker faces a second isolation boundary
to reach databases. DB security group only accepts connections from app-sg.
Two walls are always better than one.

Q5: What is the difference between Security Group and NACL?
Security Group is stateful meaning return traffic is automatically allowed.
It is attached to resources, has allow rules only, and all rules evaluated
together. NACL is stateless so you must explicitly allow both inbound and
outbound for each flow. It is attached to subnets, supports deny rules,
and rules are evaluated in order by number. Enterprise uses both layers.

Q6: Why use security_groups reference instead of cidr_blocks?
Security group reference is membership-based not IP-based. When ALB scales
from 2 to 20 instances or moves subnet the rule works automatically because
it checks group membership not IP address. CIDR-based rules break when IPs
change and allow any IP in the range not just your ALB instances.

Q7: What is ALB and when would you use NLB instead?
ALB is Layer 7 and understands HTTP - it routes by URL path, headers, and
hostname. Use ALB for web apps, REST APIs, microservices. NLB is Layer 4
and handles raw TCP/UDP packets at extreme speed for millions of connections.
Use NLB for gaming, IoT, or real-time systems where HTTP routing is not needed.

Q8: What are Terraform modules and why use them?
Modules are reusable packages of Terraform code with inputs, logic, and
outputs - like functions in programming. Write VPC code once in a module,
call it from dev staging and prod with different variables. One security
fix updates all environments. Prevents configuration drift between
environments which is a major source of security incidents in enterprise.

Q9: What happens if you delete 0.0.0.0/0 from public route table?
ALB loses internet connectivity immediately. Users get 503 or connection
timeout errors. App servers and databases continue running but no requests
can reach the application. This is why route table changes require change
control approval in enterprise - a single deletion takes down everything.

Q10: How does a web request flow through a 3-tier VPC?
User hits domain, DNS resolves to ALB public IP, request enters through
IGW to ALB in public subnet, ALB health checks targets and forwards to
healthy app server in private subnet on port 8080, app server queries
database in data subnet on port 5432, response travels back same path,
user sees the page. Each hop is controlled by security group rules.
---

## Day 2B — VPC Endpoints (Advanced Networking)

### What Was Learned
VPC Endpoints keep traffic between private subnet resources and AWS services
like S3 and DynamoDB entirely within the AWS private network.
Code written and commented out in modules/vpc/main.tf for real AWS use.

### Why VPC Endpoints Matter

Without endpoint — payment service to S3:
    payment service (10.0.2.24)
      ? NAT Gateway
      ? public internet  ? compliance fail for PCI-DSS, HIPAA
      ? S3

With endpoint — payment service to S3:
    payment service (10.0.2.24)
      ? VPC Endpoint (special S3 route in route table)
      ? AWS private backbone  ? never touches public internet
      ? S3

### Two Types of VPC Endpoints

    Gateway Endpoint
      Free
      Only S3 and DynamoDB
      Adds a route in your route table
      NOT a physical component — just a routing rule
      Zero application code changes needed

    Interface Endpoint (PrivateLink)
      Costs $0.01 per hour plus $0.01 per GB
      Works for 100+ AWS services (SQS, SNS, Secrets Manager etc)
      Creates an ENI with private IP inside your subnet
      App calls private IP instead of public endpoint

### How Gateway Endpoint Works
    Before endpoint — private route table:
      10.0.0.0/16               ? local
      0.0.0.0/0                 ? NAT Gateway

    After endpoint — private route table:
      10.0.0.0/16               ? local
      0.0.0.0/0                 ? NAT Gateway
      com.amazonaws.us-east-1.s3 ? vpce-xxxxxxxx  ? new route added

    Your application code does NOT change
    Same S3 URL in your code
    AWS intercepts the call at route table level
    Redirects through private endpoint automatically

### NAT vs VPN vs VPC Endpoint — Critical Difference
    NAT Gateway
      only translates IP addresses
      does NOT encrypt data
      does NOT create private tunnel
      traffic still travels public internet after NAT
      hides your private IP but not the data path

    VPN
      encrypts entire packet end to end
      creates secure tunnel over public internet
      used for on-premises to AWS connectivity (hybrid cloud)
      NOT used for service to service inside AWS

    VPC Endpoint
      traffic never leaves AWS network
      no encryption needed — physically separate network
      free for S3 and DynamoDB
      fastest path — direct AWS backbone
      passes compliance audits (PCI-DSS, HIPAA, SOC2)

### When to Use Each
    VPC Endpoint  ? AWS service to AWS service (S3, DynamoDB, SQS)
    NAT Gateway   ? AWS service to external internet (Stripe, Twilio)
    VPN           ? on-premises office to AWS VPC

### Terraform Code (works on real AWS, commented out for Floci)
    resource "aws_vpc_endpoint" "s3" {
      vpc_id            = aws_vpc.main.id
      service_name      = "com.amazonaws.us-east-1.s3"
      vpc_endpoint_type = "Gateway"
      route_table_ids   = [
        aws_route_table.private.id,
        aws_route_table.data.id
      ]
    }

### Floci Limitations Discovered
| Feature | Floci Support | Real AWS |
|---------|--------------|----------|
| VPC + Subnets | Supported | Supported |
| Internet Gateway | Supported | Supported |
| Security Groups | Supported | Supported |
| Route Tables | Supported | Supported |
| NAT Gateway | NOT supported | Supported |
| VPC Endpoints | NOT supported | Supported |

### Additional Interview Questions

Q11: What is a VPC Endpoint and why use it?
A VPC Endpoint creates a private connection between your VPC and AWS
services like S3 without traffic leaving the AWS network. Gateway endpoints
for S3 and DynamoDB are free and work by adding a route to your route table.
Interface endpoints create an ENI in your subnet for other AWS services.
Critical for compliance standards like PCI-DSS that forbid payment data
from traversing public networks even if encrypted.

Q12: What is the difference between a Gateway and Interface endpoint?
Gateway endpoint is just a route rule added to your route table - free,
only for S3 and DynamoDB, no component created in subnet. Interface endpoint
creates an actual Elastic Network Interface with a private IP inside your
subnet, costs money, but works for 100+ AWS services including SQS,
Secrets Manager, and ECR.

Q13: Why does NAT not provide the same security as a VPC Endpoint?
NAT only translates IP addresses - it does not encrypt data or create a
private network path. Traffic from a private subnet through NAT still
travels over public internet infrastructure after leaving the AWS network.
VPC Endpoints route traffic over the AWS private backbone which never
touches the public internet. Compliance standards care about the network
path not just encryption.

Q14: What is the difference between NAT Gateway and VPN?
NAT translates private IPs to public IPs for outbound internet access -
it is a routing mechanism with no encryption. VPN creates an encrypted
tunnel typically used for connecting on-premises networks to AWS VPC over
public internet. NAT is for cloud resources reaching internet services.
VPN is for hybrid connectivity between data centers and cloud.
