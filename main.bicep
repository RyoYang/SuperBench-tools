@description('Name of vmss to be validated')
param vmssName string = 'yangwang1-vmss'

// todo(use function to constract vmss instances name)
@description('List of vmss instances')
param vmssInstanceNames string = 'node1 node2 ...'

@description('The master node to deploy superbench')
param masterNodeName string = 'node0'

@description('Admin name of specified vmss')
param adminUsername string = 'admin'

@description('Path of Private key in specified vmss')
param vmssPrvivateKeyPath string

// defined an existing vmss object
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-08-01' existing = {
  name: vmssName
  resource installCustomScriptExtension 'extensions@2020-06-01' = {
    name: 'ibValidation'
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
      settings: {
        fileUris: [
          'https://raw.githubusercontent.com/RyoYang/SuperBench-ibvalidation/main/deploy_superbench.sh'
        ]
        commandToExecute: 'bash deploy_superbench.sh ${adminUsername} ${vmssInstanceNames} ${masterNodeName} ${vmssPrvivateKeyPath}'
      }
    }
  }
}
