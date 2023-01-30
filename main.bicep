@description('Location for all resources.')
param location string = resourceGroup().location

@description('Whether use existing vmss')
param useExistingVmss bool = false

@description('Whether use existing Indentity')
param useExistingIdentity bool = false

@description('Name of vmss to be validated')
param vmssName string = 'yangwang1-vmss'

@description('Sku of instances in the new VM Scale Set.')
param instanceSku string = 'Standard_ND96asr_v4'

@description('Number of VM instances (100 or less). in new VM Scale Set.')
@minValue(1)
@maxValue(100)
param instanceCount int = 3

@description('Admin name of specified vmss')
param adminUsername string = 'yangwang1-vmss'

@description('Type of authentication to use on the VM. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@description('SSH Key or password for the VM. Depends authenticationType.')
@secure()
param adminPasswordOrKey string = ''

@description('The master node to deploy')
param masterNodeName string = 'yangwang1-00003A'

// todo(use function to constract vmss instances name)
@description('List of vmss instances')
param vmssInstanceNames string = 'yangwang1-000039 yangwang1-00003A yangwang1-00003B yangwang1-00003C'

@description('Path of Private key in specified vmss')
param vmssPrvivateKeyPath string = '/home/yangwang1-vmss/private_key.txt'

@description('Run ib-traffic validation benchmark on vmss')
param RunIbTrafficBenchmark bool = false

@description('Run NCCL validation benchmark on vmss')
param runNcclTestBenchmark bool = false

@allowed([
  'all_nodes'
  'pair_wise'
  'k_batch'
  'topo_aware'
])
@description('Select the Pattern of NCCL validation benchmark')
param NcclPattern string = 'all_nodes'

@description('Batch size for k-batch pattern')
param BatchSize int = 3

@description('Ibnetdiscover Path for topo-aware pattern')
param IbnetdiscoverPath string = ''

param utcValue string = utcNow() 

var addressPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.0.0/24'
var virtualNetworkName = '${vmssName}-vnet'
var publicIPAddressName = '${vmssName}-pip'
var subnetName = '${vmssName}-subnet'
var loadBalancerName = '${vmssName}-lb'
var natPoolName = '${vmssName}-natpool'
var bePoolName = '${vmssName}-bepool'
var natStartPort = 50000
var natEndPort = 51000
var natBackendPort = 22
var nicName = '${vmssName}-nic'
var ipConfigName = '${vmssName}-ipconfig'

var frontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'loadBalancerFrontEnd')
var probeName = 'sb-probe'
var probeID = '${resourceId('Microsoft.Network/loadBalancers', loadBalancerName)}/probes/${probeName}'
var lbRuleName = 'sb-lbrule'

var managedIdentityName = '${vmssName}-identity'

var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var roleAssignmentName = guid(contributorRoleId, resourceGroup().id, utcValue)

var imageReference = {
  publisher: 'microsoft-dsvm'
  offer: 'ubuntu-hpc'
  sku: '2004'
  version: 'latest'
}

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

var fileUris = 'https://raw.githubusercontent.com/RyoYang/SuperBench-tools/main/deploy_superbench.sh'

var command = 'bash deploy_superbench.sh ${adminUsername} "${vmssInstanceNames}" ${masterNodeName} ${vmssPrvivateKeyPath} ${RunIbTrafficBenchmark} ${runNcclTestBenchmark} ${NcclPattern} ${BatchSize} ${IbnetdiscoverPath}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = if (!useExistingVmss) {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2022-01-01' = if (!useExistingVmss) {
  name: publicIPAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: vmssName
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2022-01-01' = if (!useExistingVmss) {
  name: loadBalancerName
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: bePoolName
      }
    ]
    loadBalancingRules: [
      {
        name: lbRuleName
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          frontendPort: 80
          backendPort: 7000
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          protocol: 'Tcp'
          enableTcpReset: false
          loadDistribution: 'Default'
          disableOutboundSnat: false
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, bePoolName)
          }
          probe: {
            id: probeID
          }
        }
      }
    ]
    probes: [
      {
        name: probeName
        id: probeID
        properties: {
          protocol: 'Http'
          port: 7999
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 1
        }
      }
    ]
    inboundNatPools: [
      {
        name: natPoolName
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          protocol: 'Tcp'
          frontendPortRangeStart: natStartPort
          frontendPortRangeEnd: natEndPort
          backendPort: natBackendPort
        }
      }
    ]
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = if (!useExistingIdentity) {
  name: managedIdentityName
  location: location
}

resource roleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!useExistingIdentity) {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource vmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2022-03-01' = if (!useExistingVmss) {
  name: vmssName
  location: location
  sku: {
    name: instanceSku
    tier: 'Standard'
    capacity: instanceCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    singlePlacementGroup: true
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: vmssName
        adminUsername: adminUsername
        adminPassword: adminPasswordOrKey
        linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: ipConfigName
                  properties: {
                    subnet: {
                      id: virtualNetwork.properties.subnets[0].id
                    }
                    
                    loadBalancerBackendAddressPools: [
                      {
                        id: loadBalancer.properties.backendAddressPools[0].id
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: loadBalancer.properties.inboundNatPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }

      extensionProfile: {
        extensions: [
          {
            name: 'deploy-${deployment().name}'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: fileUris
                commandToExecute: command
              }
            }
          }
        ]
      }
    }
  }
}

// defined an existing vmss object
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-08-01' existing = if (useExistingVmss) {
  name: vmssName
  resource installCustomScriptExtension 'extensions@2020-06-01' = {
    name: 'sb-ib2'
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      settings: {
        fileUris: fileUris
        commandToExecute: command
      }
    }
  }
}
