output "purview_account_id" {
  description = "Resource ID of the Azure Purview account"
  value       = azurerm_purview_account.main.id
}

output "purview_account_endpoint" {
  description = "Atlas endpoint for the Purview account"
  value       = azurerm_purview_account.main.atlas_kafka_endpoint_primary_connection_string
  sensitive   = true
}

output "sensitivity_label_ids" {
  description = "Map of label name → label ID (use in DLP / retention rules)"
  value       = module.sensitivity_labels.label_ids
}

output "dlp_policy_ids" {
  description = "IDs of all DLP policies created"
  value       = module.dlp_policies.policy_ids
}

output "retention_policy_ids" {
  description = "IDs of all retention policies created"
  value       = module.retention_policies.policy_ids
}

output "audit_log_enabled" {
  description = "Whether unified audit logging is active"
  value       = module.audit_settings.audit_enabled
}
