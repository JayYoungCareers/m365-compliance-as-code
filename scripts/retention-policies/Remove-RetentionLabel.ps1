# Destroy-time counterpart to Set-RetentionLabel.ps1.
# A retention label already applied to content can't be deleted without a grace period
# (Microsoft enforces this to avoid orphaning retained content), so this only removes the
# label when Purview reports it as unused; otherwise it's left in place and just untracked.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

if (Get-ComplianceTag -Identity $env:LABEL_NAME -ErrorAction SilentlyContinue) {
    try {
        Write-Host "Removing retention label '$($env:LABEL_NAME)'"
        Remove-ComplianceTag -Identity $env:LABEL_NAME -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not remove retention label '$($env:LABEL_NAME)' (likely still applied to content): $_"
    }
}
else {
    Write-Host "Retention label '$($env:LABEL_NAME)' not found — nothing to remove"
}

Remove-ComplianceState -Path $env:STATE_FILE
