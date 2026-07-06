param environment string = 'staging'
param location string = 'eastus'

module vnet '../../modules/vnet/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    environment: environment
    location: location
    vnetAddressPrefix: '10.1.0.0/16'
    publicSubnetPrefix: '10.1.1.0/24'
    privateSubnetPrefix: '10.1.2.0/24'
    dataSubnetPrefix: '10.1.3.0/24'
  }
}

output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName