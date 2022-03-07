targetScope = 'managementGroup'

@description('The Azure region into which resources should be deployed.')
param location string

@description('The Azure subscription ID that should be used for ARM deployment script resources.')
param deploymentScriptSubscriptionId string

@description('The name of the Azure resource group that should be used for ARM deployment script resources.')
param deploymentScriptResourceGroupName string

@description('The name of the team or individual who is assigning this policy.')
param assignedBy string

var category = 'Tags'

var policySetName = 'Required Tags'
var policySetDescription = 'Enforces the required tags for resource and resource groups deployed to Azure'
var inheritTagFromSubscriptionIfMissingPolicyID = '/providers/Microsoft.Authorization/policyDefinitions/xxx' // TODO fill this in

var subscriptionLevelTags = json(loadTextContent('tags/subscription.json'))
var resourceGroupLevelTags = json(loadTextContent('tags/resource-group.json'))
var allTags = union(subscriptionLevelTags, resourceGroupLevelTags)

var resourcePolicyPolicyDefinitions = [for tag in allTags: {
  groupNames: [
    tag.name
  ]
  policyDefinitionId: inheritTagFromSubscriptionIfMissingPolicyID
  policyDefinitionReferenceId: '${tag.parameterName}ResourcePolicy'
  parameters: {
    '${tag.name}': {
      value: '[parameters(\'${tag.parameterName}\')]'
    }
  }
}]

var resourceGroupPolicyDefinitions = [for tag in allTags: {
  groupNames: [
    tag.name
  ]
  policyDefinitionId: policyDefinition.id
  policyDefinitionReferenceId: '${tag.parameterName}RGPolicy'
  parameters: {
    '${tag.name}': {
      value: '[parameters(\'${tag.parameterName}\')]'
    }
  }
}]

var policyName = 'Inherit a tag from the subscription if missing from resource group'
var policyDescription = 'Adds the specified tag with its value from the containing subscription when any resource group missing this tag is created or updated. Existing resources groups can be remediated by triggering a remediation task. If the tag exists with a different value it will not be changed.'
var policyAssignmentName = 'Required Tags'
var policyAssignmentDescription = 'Enforces the required tags for resource and resource groups deployed to Azure'
var policyAssignmentEnforcementMode = 'Default'

module arrayConverter 'arrayConverter.bicep' = {
  name: 'arrayConverter'
  scope: resourceGroup(deploymentScriptSubscriptionId, deploymentScriptResourceGroupName)
  params: {
    location: location
    allTags: allTags
  }
}

resource policySetDefinition 'Microsoft.Authorization/policySetDefinitions@2020-09-01' = {
  name: guid(policySetName)
  properties: {
    displayName: policySetName
    policyType: 'Custom'
    description: policySetDescription
    metadata: {
      version: '0.0.1'
      category: category
    }
    policyDefinitionGroups: [for tag in allTags: {
      name: tag.name
    }]
    parameters: any(arrayConverter.outputs.policySetDefinitionParameters)
    policyDefinitions: union(resourcePolicyPolicyDefinitions, resourceGroupPolicyDefinitions)
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
}

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: guid(policyName)
  properties: {
    displayName: policyName
    policyType: 'Custom'
    mode: 'All'
    description: policyDescription
    metadata: {
      version: '1.0.0'
      category: category
    }
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Name of the tag, such as "environment"'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Resources/subscriptions/resourceGroups'
          }
          {
            field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
            exists: false
          }
          {
            value: '[subscription().tags[parameters(\'tagName\')]]'
            notEquals: ''
          }
        ]
      }
      then: {
        effect: 'modify'
        details: {
          roleDefinitionIds: [
            contributorRoleDefinition.id
          ]
          operations: [
            {
              operation: 'add'
              field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
              value: '[subscription().tags[parameters(\'tagName\')]]'
            }
          ]
        }
      }
    }
  }
}

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: policyAssignmentName
    description: policyAssignmentDescription
    enforcementMode: policyAssignmentEnforcementMode
    metadata: {
      version: '0.0.1'
      assignedBy: assignedBy
    }
    policyDefinitionId: policySetDefinition.id
    nonComplianceMessages: any(arrayConverter.outputs.policyAssignmentNonComplianceMessages)
  }
}
