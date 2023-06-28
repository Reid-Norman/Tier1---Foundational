targetScope = 'subscription'
param rgName string
param location string

@description('Name for the Log Analytics workspace')
param workspaceName string

@description('Pricing tier: pergb2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param pricingTierLA string = 'PerGB2018'

@description('Commitment tier')
@allowed([
  100
  200
  300
  400
  500
  1000
  2000
  5000
])
param capacityReservationLA int = 100

@description('Pricing tier: pergb2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
@allowed([
  'CapacityReservation'
  'PerGB'
])
param pricingTierSentinel string = 'PerGB'

@description('Commitment tier')
@allowed([
  100
  200
  300
  400
  500
  1000
  2000
  5000
])
param capacityReservationSentinel int = 100

@description('The kind of data connectors that can be deployed via ARM templates are the following: ["AzureActivityLog","SecurityInsightsSecurityEventCollectionConfiguration","WindowsFirewall","DnsAnalytics"], Reference: https://docs.microsoft.com/azure/templates/microsoft.operationalinsights/2020-03-01-preview/workspaces/datasources#microsoftoperationalinsightsworkspacesdatasources-object')
param enableDataConnectors array = []

@description('Severity levels desired for Analytics Rules')
param severityLevels array = []

@description('Daily ingestion limit in GBs. This limit doesn\'t apply to the following tables: SecurityAlert, SecurityBaseline, SecurityBaselineSummary, SecurityDetection, SecurityEvent, WindowsFirewall, MaliciousIPCommunication, LinuxAuditLog, SysmonEvent, ProtectionStatus, WindowsEvent')
param dailyQuota int

@description('Number of days of retention. Workspaces in the legacy Free pricing tier can only have 7 days.')
@minValue(7)
@maxValue(730)
param dataRetention int = 90

@description('If set to true when changing retention to 30 days, older data will be immediately deleted. Use this with extreme caution. This only applies when retention is being set to 30 days.')
param immediatePurgeDataOn30Days bool = true

@description('The list of Content Hub 1st party solutions to deploy.')
param enableSolutions1P array = []

@description('The list of Content Hub Essentials solutions to deploy.')
param enableSolutionsEssentials array = []

@description('The list of Content Hub Training solutions to deploy.')
param enableSolutionsTraining array = []

@description('The list of data types to enable for Azure AD connector')
param aadStreams array = []

@description('Whether or not UEBA should be enabled')
param enableUeba bool = true

@description('Array of identity providers to be synched with UEBA. Valid identity providers are \'ActiveDirectory\' and \'AzureActiveDirectory\'')
param identityProviders array = []
param enableDiagnostics bool

@description('Enable ML Behavior Analytics rules')
param enableMLAlerts bool = false

@description('Enable Scheduled analytics rules')
param enableScheduledAlerts bool = false

@description('The location of resources')
param _artifactsLocation string = 'https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Tools/Sentinel-All-In-One/'

resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgName
  location: location
  properties: {}
}

module workspaceCreation '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), 'v2/LinkedTemplates/workspace.json')]*/ = {
  name: 'workspaceCreation'
  scope: resourceGroup(rgName)
  params: {
    workspaceName: workspaceName
    pricingTierLA: pricingTierLA
    pricingTierSentinel: pricingTierSentinel
    dailyQuota: dailyQuota
    dataRetention: dataRetention
    immediatePurgeDataOn30Days: immediatePurgeDataOn30Days
    capacityReservationLA: capacityReservationLA
    capacityReservationSentinel: capacityReservationSentinel
    location: location
  }
  dependsOn: [
    rg
  ]
}

module settings '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), 'v2/LinkedTemplates/settings.json')]*/ = {
  name: 'settings'
  scope: resourceGroup(rgName)
  params: {
    workspaceName: workspaceName
    enableUeba: enableUeba
    identityProviders: identityProviders
    enableDiagnostics: enableDiagnostics
  }
  dependsOn: [
    workspaceCreation
  ]
}

module enableDataConnectors_resource '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), 'v2/LinkedTemplates/dataConnectors.json')]*/ = if (!empty(enableDataConnectors)) {
  name: 'enableDataConnectors'
  scope: resourceGroup(rgName)
  params: {
    dataConnectorsKind: enableDataConnectors
    aadStreams: aadStreams
    workspaceName: workspaceName
    tenantId: subscription().tenantId
    subscriptionId: subscription().subscriptionId
    location: location
  }
  dependsOn: [
    workspaceCreation
    enableSolutionsAndAlerts
  ]
}

module enableSolutionsAndAlerts '?' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), 'v2/LinkedTemplates/solutionsAndAlerts.json')]*/ = if ((!empty(enableSolutions1P)) || (!empty(enableSolutionsEssentials)) || (!empty(enableSolutionsTraining))) {
  name: 'enableSolutionsAndAlerts'
  scope: resourceGroup(rgName)
  params: {
    enableSolutions1P: replace(replace(string(enableSolutions1P), '[', ''), ']', '')
    enableSolutionsEssentials: replace(replace(string(enableSolutionsEssentials), '[', ''), ']', '')
    enableSolutionsTraining: replace(replace(string(enableSolutionsTraining), '[', ''), ']', '')
    workspaceName: workspaceName
    severityLevels: replace(replace(string(severityLevels), '[', ''), ']', '')
    enableAlerts: enableScheduledAlerts
    location: location
  }
  dependsOn: [
    workspaceCreation
    rg
  ]
}

output workspaceName string = workspaceName
output dataConnectorsList string = replace(replace(string(enableDataConnectors), '"', ''), '[', '')