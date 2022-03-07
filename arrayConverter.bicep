param location string = resourceGroup().location

param allTags array

var policyAssignmentNonComplianceMessage1 = {
  message: 'A required tag is missing.'
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'arrayConverter'
  location: location
  kind: 'AzureCLI'
  properties: {
    scriptContent: loadTextContent('scripts/arrayConverter.sh')
    environmentVariables: [
      {
        name: 'allTags'
        value: string(allTags)
      }
    ]
    azCliVersion: '2.9.1'
    retentionInterval: 'P1D'
  }
}

output policySetDefinitionParameters array = deploymentScript.properties.outputs.policySetDefinitionParameters
output policyAssignmentNonComplianceMessages array = union(array(policyAssignmentNonComplianceMessage1), deploymentScript.properties.outputs.policyAssignmentNonComplianceMessagesResourcePolicy, deploymentScript.properties.outputs.policyAssignmentNonComplianceMessagesRGPolicy)
