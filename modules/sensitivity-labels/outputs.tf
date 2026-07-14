output "label_ids" {
  description = "Map of label name → label ID (read back from the local compliance-state cache written by Set-SensitivityLabel.ps1)"
  value       = { for name, f in data.local_file.label_state : name => jsondecode(f.content).id }
}

output "policy_id" {
  description = "ID of the org-wide label policy"
  value       = jsondecode(data.local_file.label_policy_state.content).id
}
