output "policy_ids" {
  description = "Map of retention policy name → ID (read back from the local compliance-state cache written by Set-RetentionPolicy.ps1)"
  value       = { for name, f in data.local_file.policy_state : name => jsondecode(f.content).id }
}

output "label_ids" {
  description = "Map of retention label name → ID (read back from the local compliance-state cache written by Set-RetentionLabel.ps1)"
  value       = { for name, f in data.local_file.label_state : name => jsondecode(f.content).id }
}
