param environment string = 'dev'
param location string    = 'eastus'
param vnetAddressPrefix string = '10.0.0.0/16'
param publicSubnetPrefix string = '10.0.1.0/24'
param privateSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
    name: '${environment}-vnet'
    location: location
    properties: {
        addressSpace: {
            addressPrefixes: [
                vnetAddressPrefix
            ]

        }
        subnets: [
            {
                name: '${environment}-public-subnet'
                properties: {
                    addressPrefix: publicSubnetPrefix
                }
            }
                        {
                name: '${environment}-private-subnet'
                properties: {
                    addressPrefix: privateSubnetPrefix
                }
            }
                {
                name: '${environment}-data-subnet'
                properties: {
                    addressPrefix: dataSubnetPrefix
                }
            }
        ]
    }
    tags: {
        environment: environment
        managedBy: 'bicep'
    }
}

resource nsgPublic 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${environment}-public-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-http'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'allow-https'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource nsgPrivate 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${environment}-private-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-from-public-subnet'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: publicSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'deny-internet-inbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

resource nsgData 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${environment}-data-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-from-private-subnet'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: privateSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '5432'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managedBy: 'bicep'
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output publicSubnetId string = vnet.properties.subnets[0].id
output privateSubnetId string = vnet.properties.subnets[1].id
output dataSubnetId string = vnet.properties.subnets[2].id
output nsgPublicId string = nsgPublic.id
output nsgPrivateId string = nsgPrivate.id
output nsgDataId string = nsgData.id