# Creates or updates a retention policy and publishes a retention label to it
# (New/Set-RetentionCompliancePolicy + New/Set-RetentionComplianceRule -PublishComplianceTag).

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

$p = $env:POLICY_JSON | ConvertFrom-Json

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existingPolicy = Get-RetentionCompliancePolicy -Identity $p.name -ErrorAction SilentlyContinue

$locationParams = @{}
if ($p.locations.exchange)      { $locationParams.ExchangeLocation      = "All" }
if ($p.locations.sharepoint)    { $locationParams.SharePointLocation    = "All" }
if ($p.locations.onedrive)      { $locationParams.OneDriveLocation      = "All" }
if ($p.locations.teams_channel) { $locationParams.TeamsChannelLocation  = "All" }
if ($p.locations.teams_chat)    { $locationParams.TeamsChatLocation     = "All" }

if (-not $existingPolicy) {
    Write-Host "Creating retention policy '$($p.name)'"
    New-RetentionCompliancePolicy -Name $p.name -Comment $p.comment @locationParams | Out-Null
}
else {
    Write-Host "Updating retention policy '$($p.name)'"
    Set-RetentionCompliancePolicy -Identity $p.name -Comment $p.comment | Out-Null
}

$existingRule = Get-RetentionComplianceRule -Identity $p.rule_name -ErrorAction SilentlyContinue

if (-not $existingRule) {
    Write-Host "Publishing retention label '$($p.label_name)' to policy '$($p.name)'"
    New-RetentionComplianceRule -Name $p.rule_name -Policy $p.name -PublishComplianceTag $p.label_name | Out-Null
}
else {
    Write-Host "Retention rule '$($p.rule_name)' already publishes '$($p.label_name)' — nothing to update"
}

$result = Get-RetentionCompliancePolicy -Identity $p.name

Write-ComplianceState -Path $env:STATE_FILE -State @{
    name = $p.name
    id   = [string]$result.Guid
}

Write-Host "Retention policy '$($p.name)' ready (id: $($result.Guid))"
