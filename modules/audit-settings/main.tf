# ─── Audit Settings ───────────────────────────────────────────────────────────
# Enables Microsoft Purview unified audit logging. This is a tenant-wide switch
# (Set-AdminAuditLogConfig) with no ARM or Graph equivalent, so it's wrapped the same way
# as the other compliance modules: a terraform_data resource whose local-exec provisioner
# shells out to Security & Compliance PowerShell. See scripts/audit-settings/*.ps1.

resource "terraform_data" "unified_audit_log" {
  input = {
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${path.root}/.compliance-state/audit-settings/unified-audit-log.json"
    remove_script          = "${path.module}/../../scripts/audit-settings/Remove-AuditConfig.ps1"
  }

  triggers_replace = [var.environment]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/audit-settings/Set-AuditConfig.ps1"

    environment = {
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = self.input.remove_script

    environment = {
      STATE_FILE = self.input.state_file
    }
  }
}

data "local_file" "audit_state" {
  filename   = terraform_data.unified_audit_log.output.state_file
  depends_on = [terraform_data.unified_audit_log]
}

# ─── Diagnostic Export (optional) ─────────────────────────────────────────────
# Forwards Purview account activity to a Log Analytics workspace for SIEM integration.
# This part IS a real ARM resource (azurerm_monitor_diagnostic_setting) — unlike the
# Security & Compliance settings above, Azure Monitor diagnostic categories for
# Microsoft.Purview/accounts are genuinely provider-native.

resource "azurerm_monitor_diagnostic_setting" "purview_audit" {
  count = var.log_analytics_workspace_id != "" && var.purview_account_id != "" ? 1 : 0

  name               = "purview-audit-export-${var.environment}"
  target_resource_id = var.purview_account_id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DataSensitivityLogEvent"
  }

  enabled_log {
    category = "ScanStatusLogEvent"
  }

  # Category value is "Security" — its display name in the portal is "PurviewAccountAuditEvents".
  enabled_log {
    category = "Security"
  }
}
