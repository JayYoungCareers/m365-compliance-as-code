# Enables unified audit log ingestion via Security & Compliance PowerShell
# (Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true). There's no ARM or Graph
# equivalent for this tenant-wide switch.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

Write-Host "Enabling unified audit log ingestion"
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true | Out-Null

$result = Get-AdminAuditLogConfig

Write-ComplianceState -Path $env:STATE_FILE -State @{
    enabled = [bool]$result.UnifiedAuditLogIngestionEnabled
}

Write-Host "Unified audit log ingestion enabled: $($result.UnifiedAuditLogIngestionEnabled)"
