# Destroy-time counterpart to Set-DlpPolicy.ps1.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

if (Get-DlpComplianceRule -Identity $env:RULE_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing DLP rule '$($env:RULE_NAME)'"
    Remove-DlpComplianceRule -Identity $env:RULE_NAME -Confirm:$false
}

if (Get-DlpCompliancePolicy -Identity $env:POLICY_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing DLP policy '$($env:POLICY_NAME)'"
    Remove-DlpCompliancePolicy -Identity $env:POLICY_NAME -Confirm:$false
}
else {
    Write-Host "DLP policy '$($env:POLICY_NAME)' not found — nothing to remove"
}

Remove-ComplianceState -Path $env:STATE_FILE
