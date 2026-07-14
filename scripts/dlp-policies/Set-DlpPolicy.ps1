# Creates or updates one DLP compliance policy + its single rule via Security & Compliance
# PowerShell (New/Set-DlpCompliancePolicy, New/Set-DlpComplianceRule).
#
# NOTE: the sensitivity-label-as-condition block (sensitivitylabels group inside
# ContentContainsSensitiveInformation) matches Microsoft Learn's documented example for
# "Use sensitivity labels as conditions in DLP policies" as of this writing — verify against
# `Get-Command New-DlpComplianceRule -Syntax` on your installed module version, this is one
# of the more frequently-revised corners of the Compliance PowerShell surface.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

$p = $env:POLICY_JSON | ConvertFrom-Json

Connect-CompliancePS `
    -TenantId $env:TENANT_ID `
    -AppId $env:APP_ID `
    -CertificateThumbprint $env:CERT_THUMBPRINT `
    -Organization $env:ORGANIZATION

# ── Policy container ───────────────────────────────────────────────────────────

$existingPolicy = Get-DlpCompliancePolicy -Identity $p.name -ErrorAction SilentlyContinue

if (-not $existingPolicy) {
    Write-Host "Creating DLP policy '$($p.name)'"
    New-DlpCompliancePolicy `
        -Name $p.name `
        -Comment $p.comment `
        -Mode $p.mode `
        -ExchangeLocation "All" `
        -SharePointLocation "All" `
        -OneDriveLocation "All" `
        -TeamsLocation "All" | Out-Null
}
else {
    Write-Host "Updating DLP policy '$($p.name)'"
    Set-DlpCompliancePolicy -Identity $p.name -Comment $p.comment -Mode $p.mode | Out-Null
}

# ── Rule ────────────────────────────────────────────────────────────────────────

$sensitiveInfoTypes = @()
foreach ($sit in $p.rule.sensitive_info_types) {
    $sensitiveInfoTypes += @{
        Name             = $sit.name
        minCount         = "$($sit.min_count)"
        Confidencelevel  = $sit.confidence_level
    }
}

if ($p.rule.label_ids -and $p.rule.label_ids.Count -gt 0) {
    $sensitiveInfoTypes += @{
        Name             = "Sensitivity Label"
        sensitivitylabels = @($p.rule.label_ids | ForEach-Object { @{ name = $_; type = "Sensitivity" } })
    }
}

$blockAccess = $p.mode -eq "Enable"

$ruleParams = @{
    Name                          = $p.rule.name
    Policy                        = $p.name
    Priority                      = [int]$p.rule.priority
    ContentContainsSensitiveInformation = $sensitiveInfoTypes
    AccessScope                  = $p.rule.access_scope
    BlockAccess                  = $blockAccess
    NotifyUser                   = @("LastModifier")
    NotifyEmailCustomText        = $p.rule.notify_message
    GenerateIncidentReport       = @($p.rule.report_to)
    IncidentReportContent        = @("Title", "Severity", "RulesMatched", "MatchedItem", "Occurrence")
    ReportSeverityLevel          = $p.rule.severity
}

if ($blockAccess) {
    $ruleParams.BlockAccessScope = "All"
}

$existingRule = Get-DlpComplianceRule -Identity $p.rule.name -ErrorAction SilentlyContinue

if (-not $existingRule) {
    Write-Host "Creating DLP rule '$($p.rule.name)'"
    New-DlpComplianceRule @ruleParams | Out-Null
}
else {
    Write-Host "Updating DLP rule '$($p.rule.name)'"
    $ruleParams.Remove("Policy") | Out-Null
    $ruleParams.Identity = $p.rule.name
    Set-DlpComplianceRule @ruleParams | Out-Null
}

$result = Get-DlpCompliancePolicy -Identity $p.name

Write-ComplianceState -Path $env:STATE_FILE -State @{
    name = $p.name
    id   = [string]$result.Guid
}

Write-Host "DLP policy '$($p.name)' ready (id: $($result.Guid))"
