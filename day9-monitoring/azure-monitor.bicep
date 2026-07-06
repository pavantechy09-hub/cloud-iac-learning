param environment string = 'dev'
param location string = 'eastus'
param alertEmail string = 'oncall@firstnationalbank.com'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${environment}-bank-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${environment}-bank-alerts'
  location: 'global'
  properties: {
    groupShortName: 'BankAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'OnCall Engineer'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource functionErrorAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${environment}-function-errors'
  location: 'global'
  properties: {
    description: 'Azure Function error rate too high'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FunctionErrors'
          metricName: 'FunctionExecutionUnits'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource sqlCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${environment}-sql-cpu-high'
  location: 'global'
  properties: {
    description: 'Azure SQL CPU too high'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'SqlCpu'
          metricName: 'cpu_percent'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

output workspaceId string = logAnalyticsWorkspace.id
output actionGroupId string = actionGroup.id