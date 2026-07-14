# Destroy-time counterpart to Set-RetentionPolicy.ps1.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

if (Get-RetentionComplianceRule -Identity $env:RULE_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing retention rule '$($env:RULE_NAME)'"
    Remove-RetentionComplianceRule -Identity $env:RULE_NAME -Confirm:$false
}

if (Get-RetentionCompliancePolicy -Identity $env:POLICY_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing retention policy '$($env:POLICY_NAME)'"
    Remove-RetentionCompliancePolicy -Identity $env:POLICY_NAME -Confirm:$false
}
else {
    Write-Host "Retention policy '$($env:POLICY_NAME)' not found — nothing to remove"
}

Remove-ComplianceState -Path $env:STATE_FILE
