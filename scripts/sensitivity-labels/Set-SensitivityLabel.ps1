# Creates or updates a single Microsoft Purview sensitivity label via Security & Compliance
# PowerShell. Invoked by modules/sensitivity-labels as a terraform_data local-exec provisioner.
#
# NOTE: content-marking and encryption parameter names below (ApplyContentMarking*,
# ApplyWatermarking*, Encryption*) match Microsoft's documented New-Label/Set-Label reference
# as of this writing. Purview compliance cmdlets change fairly often between module versions —
# run `Get-Command Set-Label -Syntax` against your installed ExchangeOnlineManagement version
# before relying on this in a real tenant.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

$label = $env:LABEL_JSON | ConvertFrom-Json

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

$existing = Get-Label -Identity $label.name -ErrorAction SilentlyContinue

$commonParams = @{
    DisplayName = $label.display_name
    Tooltip     = $label.tooltip
    Comment     = $label.description
}

if (-not $existing) {
    Write-Host "Creating sensitivity label '$($label.name)'"
    New-Label -Name $label.name @commonParams | Out-Null
}
else {
    Write-Host "Updating sensitivity label '$($label.name)'"
}

$updateParams = @{
    Identity = $label.name
    Priority = [int]$label.priority
} + $commonParams

if ($label.mark_content) {
    $updateParams += @{
        ApplyContentMarkingHeaderEnabled    = $true
        ApplyContentMarkingHeaderText       = $label.display_name
        ApplyContentMarkingHeaderFontSize   = 10
        ApplyContentMarkingHeaderFontColor  = $label.color
        ApplyContentMarkingHeaderAlignment  = "Center"

        ApplyContentMarkingFooterEnabled    = $true
        ApplyContentMarkingFooterText       = "Classification: $($label.display_name)"
        ApplyContentMarkingFooterFontSize   = 10
        ApplyContentMarkingFooterFontColor  = $label.color
        ApplyContentMarkingFooterAlignment  = "Center"
    }

    if ($label.watermark_text) {
        $updateParams += @{
            ApplyWatermarkingEnabled   = $true
            ApplyWatermarkingText      = $label.watermark_text
            ApplyWatermarkingFontSize  = 14
            ApplyWatermarkingFontColor = $label.color
            ApplyWatermarkingLayout    = "Diagonal"
        }
    }
}
else {
    $updateParams += @{
        ApplyContentMarkingHeaderEnabled = $false
        ApplyContentMarkingFooterEnabled = $false
        ApplyWatermarkingEnabled         = $false
    }
}

if ($label.encrypt) {
    $updateParams += @{
        EncryptionEnabled        = $true
        EncryptionProtectionType = "Template"
        EncryptionRightsDefinitions = "$($env:ORGANIZATION):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
    }
}
else {
    $updateParams += @{ EncryptionEnabled = $false }
}

Set-Label @updateParams | Out-Null

$result = Get-Label -Identity $label.name

Write-ComplianceState -Path $env:STATE_FILE -State @{
    name         = $label.name
    id           = [string]$result.ImmutableId
    display_name = $label.display_name
    updated_by   = "terraform"
}

Write-Host "Sensitivity label '$($label.name)' ready (id: $($result.ImmutableId))"
