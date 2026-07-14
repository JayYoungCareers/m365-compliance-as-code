output "audit_enabled" {
  description = "Whether the unified audit log is active (read back from the local compliance-state cache written by Set-AuditConfig.ps1)"
  value       = jsondecode(data.local_file.audit_state.content).enabled
}
