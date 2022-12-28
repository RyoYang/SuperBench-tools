@description('Name of vmss to be validated')
param vmssName string = 'yangwang1-vmss'

// todo(use function to constract vmss instances name)
@description('List of vmss instances')
param vmssInstanceNames array

@description('Admin name of specified vmss')
param adminUsername string = 'admin'

@description('Private key of specified vmss')
param vmssPrvivateKey string

// defined an existing vmss object
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-08-01' existing = {
  name: vmssName
  resource installCustomScriptExtension 'extensions@2020-06-01' = {
    name: 'IB Validation'
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      autoUpgradeMinorVersion: true
      settings: {
        fileUris: [
          'https://raw.githubusercontent.com/RyoYang/SuperBench-ibvalidation/main/deploy_superbench.sh'
        ]
        commandToExecute: 'bash deploy_superbench.sh ${vmssInstanceNames} ${adminUsername} ${vmssPrvivateKey}'
      }
    }
  }
}
