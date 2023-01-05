param vmssName string = 'yangwang1-vmss'

resource vmssName_InstallCustomScript 'Microsoft.Compute/virtualMachineScaleSets/extensions@2020-06-01' = {
  name: '${vmssName}/InstallCustomScript'
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/RyoYang/SuperBench-ibvalidation/main/deploy_superbench.sh'
      ]
      commandToExecute: 'bash deploy_superbench.sh'
    }
  }
}