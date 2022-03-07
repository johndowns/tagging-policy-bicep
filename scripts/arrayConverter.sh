policySetDefinitionParameters=$(jq 'map( { (.parameterName|tostring): {"type": "String", "metadata": {"displayName": (.name|tostring), "description": (.description|tostring)}, "allowedValues": [(.name|tostring)], "defaultValue": (.name|tostring)} } ) | [add]' <(echo "$allTags"))
policyAssignmentNonComplianceMessagesResourcePolicy=$(jq $'map(select(.isRequired) | { "message": "A required tag is missing, \'\\(.name|tostring)\' - \\(.description|tostring), Example Values: \\(.exampleValues|join(", "))", "policyDefinitionReferenceId": "\\(.parameterName|tostring)ResourcePolicy" })' <(echo "$allTags"))
policyAssignmentNonComplianceMessagesRGPolicy=$(jq $'map(select(.isRequired) | { "message": "A required tag is missing, \'\\(.name|tostring)\' - \\(.description|tostring), Example Values: \\(.exampleValues|join(", "))", "policyDefinitionReferenceId": "\\(.parameterName|tostring)RGPolicy" })' <(echo "$allTags"))

echo "{ \"policySetDefinitionParameters\": $policySetDefinitionParameters, \"policyAssignmentNonComplianceMessagesResourcePolicy\": $policyAssignmentNonComplianceMessagesResourcePolicy, \"policyAssignmentNonComplianceMessagesRGPolicy\": $policyAssignmentNonComplianceMessagesRGPolicy }" > $AZ_SCRIPTS_OUTPUT_PATH
