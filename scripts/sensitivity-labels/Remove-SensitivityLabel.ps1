# Destroy-time counterpart to Set-SensitivityLabel.ps1.
# Sensitivity labels are rarely hard-deleted in production tenants (deleting a label that's
# already applied to content orphans that content's classification), so this disables the
# label rather than removing it outright, and always clears the local state cache.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existing = Get-Label -Identity $env:LABEL_NAME -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "Disabling sensitivity label '$($env:LABEL_NAME)' (labels are not hard-deleted by default)"
    Set-Label -Identity $env:LABEL_NAME -Disabled $true | Out-Null
}
else {
    Write-Host "Sensitivity label '$($env:LABEL_NAME)' not found — nothing to remove"
}

Remove-ComplianceState -Path $env:STATE_FILE
