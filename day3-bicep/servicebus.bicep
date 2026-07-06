param environment string = 'dev'
param location string = 'eastus'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: '${environment}-servicebus'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource paymentQueue 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = {
  parent: serviceBusNamespace
  name: 'payment-queue'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT1M'
    deadLetteringOnMessageExpiration: true
  }
}

resource notificationTopic 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' = {
  parent: serviceBusNamespace
  name: 'notification-topic'
  properties: {
    defaultMessageTimeToLive: 'P1D'
  }
}

output serviceBusId string = serviceBusNamespace.id
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint
output paymentQueueId string = paymentQueue.id