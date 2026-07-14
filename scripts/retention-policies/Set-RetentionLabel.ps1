# Creates or updates a retention label (New-ComplianceTag / Set-ComplianceTag). Retention
# labels are the modern replacement for the old "retention compliance tag" terminology —
# ComplianceTag is still the cmdlet noun.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

$label = $env:LABEL_JSON | ConvertFrom-Json

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existing = Get-ComplianceTag -Identity $label.name -ErrorAction SilentlyContinue

$params = @{
    RetentionAction = $label.retention_action
    RetentionDuration = [int]$label.retention_duration
    RetentionType   = $label.retention_type
    IsRecordLabel   = $label.is_record
    Comment         = $label.comment
}

if (-not $existing) {
    Write-Host "Creating retention label '$($label.name)'"
    New-ComplianceTag -Name $label.name @params | Out-Null
}
else {
    Write-Host "Updating retention label '$($label.name)'"
    Set-ComplianceTag -Identity $label.name @params | Out-Null
}

$result = Get-ComplianceTag -Identity $label.name

Write-ComplianceState -Path $env:STATE_FILE -State @{
    name = $label.name
    id   = [string]$result.Guid
}

Write-Host "Retention label '$($label.name)' ready (id: $($result.Guid))"
