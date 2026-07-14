# Destroy-time counterpart to Set-LabelPolicy.ps1 — unpublishes the org-wide label policy.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existing = Get-LabelPolicy -Identity $env:POLICY_NAME -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "Removing label policy '$($env:POLICY_NAME)'"
    Remove-LabelPolicy -Identity $env:POLICY_NAME -Confirm:$false
}
else {
    Write-Host "Label policy '$($env:POLICY_NAME)' not found — nothing to remove"
}

Remove-ComplianceState -Path $env:STATE_FILE
