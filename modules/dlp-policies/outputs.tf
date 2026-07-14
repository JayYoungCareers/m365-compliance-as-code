output "policy_ids" {
  description = "Map of DLP policy name → ID (read back from the local compliance-state cache written by Set-DlpPolicy.ps1)"
  value       = { for name, f in data.local_file.policy_state : name => jsondecode(f.content).id }
}
