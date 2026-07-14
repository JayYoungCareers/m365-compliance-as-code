# Destroy-time counterpart to Set-AuditConfig.ps1.
# Intentionally does NOT disable unified audit logging on `terraform destroy` — turning off
# org-wide audit ingestion is a security-relevant, tenant-wide action that shouldn't be a
# side effect of tearing down this module. This just drops the local state cache; disable
# the audit log deliberately and separately if that's really the intent.

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Connect-Compliance.ps1"

Write-Warning "Leaving unified audit log ingestion enabled (not disabling on destroy) — see Remove-AuditConfig.ps1 for why."

Remove-ComplianceState -Path $env:STATE_FILE
