# Publishes the org-wide sensitivity label policy (New-LabelPolicy / Set-LabelPolicy).
# Fine-grained UX behavior (mandatory labeling, downgrade justification, Outlook default
# label, etc.) isn't exposed as top-level cmdlet parameters — it's set via the
# -AdvancedSettings hashtable, which is the documented mechanism for these policy knobs.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

$policy = $env:POLICY_JSON | ConvertFrom-Json

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existing = Get-LabelPolicy -Identity $policy.name -ErrorAction SilentlyContinue

if (-not $existing) {
    Write-Host "Creating label policy '$($policy.name)'"
    New-LabelPolicy `
        -Name $policy.name `
        -Labels $policy.label_names `
        -Comment $policy.description `
        -ExchangeLocation "All" `
        -SharePointLocation "All" `
        -OneDriveLocation "All" `
        -ModernGroupLocation "All" | Out-Null
}
else {
    Write-Host "Updating label policy '$($policy.name)'"
    Set-LabelPolicy -Identity $policy.name -Labels $policy.label_names | Out-Null
}

$mandatoryFlag = if ($policy.mandatory) { "true" } else { "false" }

Set-LabelPolicy -Identity $policy.name -AdvancedSettings @{
    mandatory                     = $mandatoryFlag
    requiredowngradejustification = "true"
    PowerBIMandatory              = "false"
} | Out-Null

$result = Get-LabelPolicy -Identity $policy.name

Write-ComplianceState -Path $env:STATE_FILE -State @{
    name = $policy.name
    id   = [string]$result.Guid
}

Write-Host "Label policy '$($policy.name)' ready (id: $($result.Guid))"
