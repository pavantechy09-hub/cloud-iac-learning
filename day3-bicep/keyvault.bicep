param environment string = 'dev'
param location string = 'eastus'
param keyVaultName string = 'kv-${environment}-demo'

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    accessPolicies: []
    enableRbacAuthorization: true
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource dbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: 'SuperSecretPassword123!'
    attributes: {
      enabled: true
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output secretUri string = dbPasswordSecret.properties.secretUri