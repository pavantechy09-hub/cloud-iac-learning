param environment string = 'dev'
param location string = 'eastus'
param functionAppName string = '${environment}-fraud-function'
param storageAccountName string = '${environment}stfunc'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${environment}-function-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
      ]
    }
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: '${environment}-bank-apim'
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'platform@firstnationalbank.com'
    publisherName: 'FirstNational Bank Platform Team'
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource fraudApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  parent: apim
  name: 'fraud-api'
  properties: {
    displayName: 'Fraud Detection API'
    path: 'fraud'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
  }
}

output functionAppId string = functionApp.id
output functionAppHostname string = functionApp.properties.defaultHostName
output apimId string = apim.id
output apimGatewayUrl string = apim.properties.gatewayUrl
output fraudApiId string = fraudApi.id