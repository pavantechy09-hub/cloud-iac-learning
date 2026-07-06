param environment string = 'dev'
param location string = 'eastus'

module vnet '../../modules/vnet/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    environment: environment
    location: location
    vnetAddressPrefix: '10.0.0.0/16'
    publicSubnetPrefix: '10.0.1.0/24'
    privateSubnetPrefix: '10.0.2.0/24'
    dataSubnetPrefix: '10.0.3.0/24'
  }
}

output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName
output publicSubnetId string = vnet.outputs.publicSubnetId
output privateSubnetId string = vnet.outputs.privateSubnetId
output dataSubnetId string = vnet.outputs.dataSubnetId
output nsgPublicId string = vnet.outputs.nsgPublicId
output nsgPrivateId string = vnet.outputs.nsgPrivateId
output nsgDataId string = vnet.outputs.nsgDataId