# Day 9 - Monitoring + Observability

## Environment
- CloudWatch alarms deployed on Floci (localhost:4566)
- Azure Monitor written in Bicep, compiled to ARM
- Dashboard not supported in Floci (code correct for real AWS)

## Start Every Day
    . D:\cloud-iac\start-env.ps1

---

## What Was Built

### AWS CloudWatch (Terraform + Floci)
    aws_sns_topic              bank-platform-alerts (email to oncall)
    aws_cloudwatch_metric_alarm x6:
      fraud-check-errors       Lambda errors > 5 in 5 mins
      fraud-check-slow         Lambda p99 > 10 seconds
      fraud-check-throttled    any Lambda throttles in 1 min
      fraud-queue-backing-up   SQS depth > 100 messages
      accounts-db-cpu-high     RDS CPU > 80%
      accounts-db-low-storage  RDS free storage < 4GB
    aws_cloudwatch_dashboard   commented out (Floci limitation)

### Azure Monitor (Bicep - compiled only)
    logAnalyticsWorkspace      central log collection, 90 day retention
    actionGroup                email alert to oncall engineer
    metricAlerts x2:
      function-errors          Azure Function error rate
      sql-cpu-high             Azure SQL CPU > 80%

---

## Core Concepts Learned

### 1. Why Monitoring Matters
    Without monitoring:
      Customer reports issue
      Support contacts engineer
      Engineer investigates manually
      Downtime: 45 minutes

    With monitoring:
      Alarm fires automatically at 2:04am
      Engineer paged at 2:04am
      Fixed by 2:15am
      Customer never noticed

### 2. CloudWatch Alarm Anatomy
    Three parts every alarm needs:
      Metric     what to measure (Lambda Errors, CPU, Queue Depth)
      Threshold  when to trigger (errors > 5, CPU > 80%)
      Action     what to do (SNS ? email/SMS/PagerDuty)

    Three alarm states:
      OK                metric below threshold, all good
      ALARM             threshold breached, action triggered
      INSUFFICIENT_DATA not enough data yet (new alarm or Lambda not invoked)

### 3. Key Alarm Fields Explained
    evaluation_periods = 2, period = 300
      Must breach threshold for 2 consecutive 5-minute windows
      = 10 minutes sustained breach before alarm fires
      Prevents false alarms from brief spikes

    statistic vs extended_statistic
      statistic = standard (Sum, Average, Maximum, Minimum, SampleCount)
      extended_statistic = percentiles (p99, p95, p50)
      Cannot use both on same alarm - causes conflict error

    p99 on Lambda duration
      99th percentile - 99% of invocations faster than this value
      Average hides outliers: 1 slow + 999 fast = average looks fine
      p99 catches the 1% of customers experiencing slow responses

    threshold = 4294967296 on storage
      4GB in bytes (4 * 1024 * 1024 * 1024)
      ComparisonOperator = LessThanThreshold (direction flipped)
      Alarm fires when storage DROPS BELOW this value

    treat_missing_data = notBreaching
      If Lambda not invoked recently, no error metrics exist
      notBreaching = assume OK when no data
      Use breaching for critical health checks
      Use notBreaching for variable workloads

    ok_actions on lambda_errors
      Sends notification when alarm RECOVERS to OK state
      "Good news - fraud check is back to normal"
      Equally important as the initial alert

### 4. SNS - How Alerts Actually Reach People
    SNS Topic = the notification hub
    SNS Subscription = who receives the notification
      Protocol options: email, SMS, HTTP, Lambda, SQS
      Enterprise: HTTP to PagerDuty or OpsGenie
      These tools manage on-call rotations and escalations

    Flow:
      Alarm breaches threshold
        -> CloudWatch publishes to SNS topic
        -> SNS delivers to all subscriptions
        -> Email arrives at oncall@firstnationalbank.com
        -> PagerDuty pages the on-call engineer
        -> Engineer gets woken up

### 5. SQS Queue Depth Alarm
    Most important operational metric for event-driven systems
    Queue depth rising means Lambda cannot keep up with incoming messages

    Queue depth = 0      Lambda processing normally
    Queue depth = 50     slightly behind, watch it
    Queue depth = 100    ALARM fires, investigate
    Queue depth = 1000   serious backlog, scale up or fix Lambda

    Root causes:
      Lambda throwing errors (messages not deleted, re-queued)
      Lambda too slow (not processing fast enough)
      Lambda throttled (hitting concurrency limit)
      Sudden spike in payments (more messages than Lambda can handle)

### 6. Azure Monitor vs CloudWatch
    CloudWatch (AWS)                Azure Monitor
    Metric Alarms                   Metric Alerts
    SNS Action                      Action Group
    Log Insights                    Log Analytics Workspace
    CloudWatch Logs                 Log Analytics (same workspace)
    Evaluation period               evaluationFrequency + windowSize
    Namespace (AWS/Lambda)          Resource scope
    Statistic (Sum, Average)        timeAggregation (Count, Average, Total)

    Key difference:
      Azure separates log collection (Log Analytics Workspace)
      from alerting (Metric Alerts + Action Groups)
      CloudWatch combines both in one service

### 7. Log Analytics Workspace
    Central repository for all Azure logs
    retentionInDays = 90
      Keep 90 days of logs for investigation and compliance
      After 90 days logs archived to cheaper storage or deleted
      Banks may require longer retention for audit

    PerGB2018 SKU
      Pay per GB of data ingested
      Alternative: Capacity Reservation (fixed price, better for high volume)
      For most workloads: PerGB2018 is cheapest starting point

### 8. Action Groups vs SNS Topics
    SNS Topic (AWS)
      Simple pub/sub
      You manage who subscribes
      Add endpoints manually

    Action Group (Azure)
      Richer notification options
      Email, SMS, Azure Function, Logic App, webhook, ITSM
      useCommonAlertSchema = true
        Standardizes alert payload format
        All monitoring tools receive same JSON structure
        Easier to parse in downstream systems

### 9. Floci Limitations in Day 9
| Feature | Floci | Real AWS |
|---------|-------|----------|
| CloudWatch alarms | Supported | Supported |
| SNS topics + subscriptions | Supported | Supported |
| CloudWatch dashboard | NOT supported | Supported |

---

## CLI Commands Used
    aws cloudwatch describe-alarms --output table
    aws cloudwatch describe-alarms --query "MetricAlarms[*].{Name:AlarmName,State:StateValue}" --output table
    aws sns list-topics --output table
    az bicep build --file azure-monitor.bicep

---

## Interview Questions and Answers

Q1: What are the three parts of a CloudWatch alarm?
Every alarm needs a metric to measure, a threshold to compare against,
and an action to take when the threshold is breached. The metric defines
what to watch such as Lambda Errors or RDS CPU. The threshold defines
when to trigger such as errors greater than 5 or CPU greater than 80
percent. The action defines what happens such as publishing to an SNS
topic which emails the on-call engineer or pages PagerDuty. The alarm
also needs evaluation configuration - how many periods must breach before
triggering to prevent false alarms from momentary spikes.

Q2: What is the difference between statistic and extended_statistic?
Statistic covers the standard aggregations: Sum, Average, Minimum,
Maximum, and SampleCount. extended_statistic covers percentile
aggregations like p99, p95, and p50. You cannot use both on the same
alarm - they conflict. For Lambda duration we use p99 because Average
hides outliers. If 999 invocations complete in 100ms and 1 takes 30
seconds, the average looks fine at about 130ms, but p99 would show the
real tail latency. Percentile metrics are essential for understanding
the experience of the slowest users.

Q3: What does INSUFFICIENT_DATA mean on a CloudWatch alarm?
INSUFFICIENT_DATA is the initial state of a new alarm before enough
data points have been collected to evaluate the threshold. It also
occurs when a service stops sending metrics, such as a Lambda function
that has not been invoked recently. The treat_missing_data setting
controls how this state is handled. notBreaching treats missing data as
OK which is appropriate for variable workloads. breaching treats missing
data as a threshold violation which is appropriate for health checks
where silence itself indicates a problem.

Q4: Why monitor SQS queue depth alongside Lambda errors?
Queue depth tells you if Lambda is keeping up with incoming messages.
Lambda errors are one reason for queue depth rising because failed
messages return to the queue and get retried. But queue depth can also
rise if Lambda is too slow, throttled, or if there is a sudden message
spike. Monitoring both together gives the full picture. If errors are
high and depth is rising, Lambda is failing to process messages. If
errors are low but depth is rising, Lambda might be throttled or too
slow. These require different responses.

Q5: What is the difference between Azure Monitor Action Groups and AWS SNS?
Both are notification hubs that alert teams when something goes wrong.
SNS is simpler - a topic with subscriptions using protocols like email,
SMS, HTTP, or Lambda. Action Groups are richer, supporting email, SMS,
Azure Functions, Logic Apps, webhooks, and ITSM tool integrations with
a standardized common alert schema. The key architectural difference is
that Azure separates log collection into Log Analytics Workspaces from
alerting in Metric Alerts and Action Groups, while CloudWatch combines
metrics, logs, and alarms in one service.

Q6: What is a Log Analytics Workspace used for in Azure?
A Log Analytics Workspace is the central repository where all Azure
resource logs, metrics, and diagnostic data are collected and stored.
All Azure Monitor alerts, Application Insights, and Security Center
findings can be correlated in one workspace using KQL queries. The
retention period controls how long data is kept - 90 days for active
investigation and compliance, with data archived to cheaper storage
afterwards. The PerGB2018 SKU bills per gigabyte ingested making it
cost-effective for variable workloads, while Capacity Reservation is
better for predictable high-volume scenarios.