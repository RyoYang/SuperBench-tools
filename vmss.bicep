@description('Location for all resources')
param location string = resourceGroup().location

@description('Size of VMs in the VM Scale Set.')
param vmSku string = 'Standard_ND96asr_v4'

@description('String used as a base for naming resources (9 characters or less). A hash is prepended to this string for some resources, and resource-specific information is appended.')
param vmssName string = 'gluonvmss'

@description('Number of VM instances (100 or less).')
@minValue(1)
@maxValue(100)
param instanceCount int = 3

@description('Whether use existing vmss')
param useExistingVmss bool = false

@description('Admin username on all VMs.')
param adminUsername string = 'gluon'

@description('Hosts to deply')
param hosts string = ''

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@description('Image tag of gluon components')
param imageTag string = 'latest'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

// Create storage container
@description('Storage Account type')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The name of the Storage Account')
param storageAccountName string = 'gluonstorage'

@description('Geneva metrics account')
param genevaMetricsAccount string = 'AzureAIInference'

@description('Geneva logs account')
param genevaLogsAccount string = 'AzureAIInference'

@description('Geneva logs namespace')
param genevaLogsNamespace string = 'AzureAIInference'

var addressPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.0.0/24'
var virtualNetworkName = '${vmssName}vnet'
var publicIPAddressName = '${vmssName}pip'
var subnetName = '${vmssName}subnet'
var loadBalancerName = '${vmssName}lb'
var natPoolName = '${vmssName}natpool'
var bePoolName = '${vmssName}bepool'
var natStartPort = 50000
var natEndPort = 51000
var natBackendPort = 22
var nicName = '${vmssName}nic'
var ipConfigName = '${vmssName}ipconfig'

var frontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'loadBalancerFrontEnd')
var probeName = 'gluon-probe'
var probeID = '${resourceId('Microsoft.Network/loadBalancers', loadBalancerName)}/probes/${probeName}'
var lbRuleName = 'gluon-lbrule'

var osType = {
  publisher: 'microsoft-dsvm'
  offer: 'ubuntu-hpc'
  sku: '2004'
  version: 'latest'
}
var imageReference = osType
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

// Create VMSS and dependency resources: VirtualNetwork, PublicIpAddress, LoadBalancer
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

param utcValue string = utcNow() 

var managedIdentityName = '${vmssName}identity'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: managedIdentityName
  location: location
}

var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var roleAssignmentName = guid(managedIdentity.name, contributorRoleId, resourceGroup().id, utcValue)

resource roleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

var containername = 'deploy'

resource sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: false
    minimumTlsVersion: 'TLS1_1'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
  resource blob 'blobServices' = {
    name: 'default'
    resource container 'containers' = {
      name: containername
    }
  }
}

var expireDatetime = dateTimeAdd(utcValue, 'P10Y')

var sasConfig = {
  signedResourceTypes: 'sco'
  signedPermission: 'rwdlacu'
  signedServices: 'b'
  signedExpiry: expireDatetime
  signedProtocol: 'https'
  keyToSign: 'key1'
}

var sasToken = sa.listAccountSas(sa.apiVersion, sasConfig).accountSasToken
var sasUrl = 'https://${sa.name}.blob.core.windows.net/?${sasToken}'
// Create Azure Container Registry
@minLength(5)
@maxLength(50)
@description('Name of the azure container registry (must be globally unique)')
param acrName string = 'gluonacr${uniqueString(resourceGroup().id)}'

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = true


@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Standard'

// azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  tags: {
    displayName: 'Container Registry'
    'container.registry': acrName
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}

var deploymentScriptName = 'gluondeployment'

resource upload 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.41.0'
    retentionInterval: 'P1D'
    timeout: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: sa.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        value: sa.listKeys().keys[0].value
      }
      {
        name: 'CONTAINER_NAME'
        value: containername
      }
      {
        name: 'DEPLOY_ZIP'
        value: loadFileAsBase64('Deploy.zip')
      }
      {
        name: 'METRICS_LOGS_PUBLISHER_ZIP'
        value: loadFileAsBase64('MetricsLogsPublisher.zip')
      }
      {
        name: 'ROUTER_ZIP'
        value: loadFileAsBase64('Router.zip')
      }
      {
        name: 'SCHEDULER_ZIP'
        value: loadFileAsBase64('Scheduler.zip')
      }
      {
        name: 'SERVICE_DOWNLOADER_ZIP'
        value: loadFileAsBase64('ServiceDownloader.zip')
      }
      {
        name: 'DEPLOY_SHELL_SCRIPT'
        value: loadFileAsBase64('deploy.sh')
      }
      {
        name: 'HOST_GENERATOR_SCRIPT'
        value: loadFileAsBase64('host_generator.py')
      }
      {
        name: 'GENEVA_CERTIFICATE'
        value: loadFileAsBase64('AzureDLInference.pfx')
      }
      {
        name: 'GLUON_KEY'
        value: loadFileAsBase64('gluon_key')
      }
    ]
    scriptContent: '''
      echo $DEPLOY_ZIP | base64 -d > /tmp/Deploy.zip
      echo $METRICS_LOGS_PUBLISHER_ZIP | base64 -d > /tmp/MetricsLogsPublisher.zip
      echo $ROUTER_ZIP | base64 -d > /tmp/Router.zip
      echo $SCHEDULER_ZIP | base64 -d > /tmp/Scheduler.zip
      echo $SERVICE_DOWNLOADER_ZIP | base64 -d > /tmp/ServiceDownloader.zip
      echo $DEPLOY_SHELL_SCRIPT | base64 -d > /tmp/deploy.sh
      echo $HOST_GENERATOR_SCRIPT | base64 -d > /tmp/host_generator.py
      echo $GENEVA_CERTIFICATE | base64 -d > /tmp/AzureDLInference.pfx
      echo $GLUON_KEY | base64 -d > /tmp/gluon_key
      az storage blob upload -f /tmp/Deploy.zip -c $CONTAINER_NAME -n Deploy.zip --overwrite
      az storage blob upload -f /tmp/MetricsLogsPublisher.zip -c $CONTAINER_NAME -n MetricsLogsPublisher.zip --overwrite
      az storage blob upload -f /tmp/Router.zip -c $CONTAINER_NAME -n Router.zip --overwrite
      az storage blob upload -f /tmp/Scheduler.zip -c $CONTAINER_NAME -n Scheduler.zip --overwrite
      az storage blob upload -f /tmp/ServiceDownloader.zip -c $CONTAINER_NAME -n ServiceDownloader.zip --overwrite
      az storage blob upload -f /tmp/deploy.sh -c $CONTAINER_NAME -n deploy.sh --overwrite
      az storage blob upload -f /tmp/host_generator.py -c $CONTAINER_NAME -n host_generator.py --overwrite
      az storage blob upload -f /tmp/AzureDLInference.pfx -c $CONTAINER_NAME -n AzureDLInference.pfx --overwrite
      az storage blob upload -f /tmp/gluon_key -c $CONTAINER_NAME -n gluon_key --overwrite
      '''
  }
}

var command = 'bash deploy.sh ${managedIdentity.properties.principalId} ${acrName} ${acr.listCredentials().passwords[0].value} ${imageTag} "${sasUrl}" ${genevaMetricsAccount} ${genevaLogsAccount} ${genevaLogsNamespace} ${adminUsername} ${resourceGroup().name} ${vmssName} "${hosts}" > /home/gluon/deploy.log'
var fileUris = [
  '${sa.properties.primaryEndpoints.blob}${containername}/MetricsLogsPublisher.zip'
  '${sa.properties.primaryEndpoints.blob}${containername}/Router.zip'
  '${sa.properties.primaryEndpoints.blob}${containername}/Scheduler.zip'
  '${sa.properties.primaryEndpoints.blob}${containername}/ServiceDownloader.zip'
  '${sa.properties.primaryEndpoints.blob}${containername}/deploy.sh'
  '${sa.properties.primaryEndpoints.blob}${containername}/host_generator.py'
  '${sa.properties.primaryEndpoints.blob}${containername}/gluon_key'
  '${sa.properties.primaryEndpoints.blob}${containername}/Deploy.zip'
]

resource vmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2022-03-01' = if (!useExistingVmss) {
  dependsOn: [
    upload
  ]
  name: vmssName
  location: location
  sku: {
    name: vmSku
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
              protectedSettings: {
                fileUris: fileUris
                commandToExecute: command
                storageAccountName: sa.name
                storageAccountKey: listKeys(sa.id, '2022-05-01').keys[0].value
              }
            }
          }
        ]
      }
    }
  }
}

// Add extention for existing vmss
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-03-01' existing = if (useExistingVmss) {
  name: vmssName
  resource installCustomScriptExtension 'extensions@2022-03-01' = {
    name: 'deploy-${deployment().name}'
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      autoUpgradeMinorVersion: true
      protectedSettings: {
        fileUris: fileUris
        commandToExecute: command
        storageAccountName: sa.name
        storageAccountKey: listKeys(sa.id, '2022-05-01').keys[0].value
      }
    }
  }
}

output managedIdentityId string = managedIdentity.id
