variable "environment" {
  type = string
}

variable "purview_account_id" {
  description = "Resource ID of the Purview account (for diagnostic export)"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace for audit export (leave blank to skip)"
  type        = string
  default     = ""
}

# ─── Security & Compliance PowerShell auth ────────────────────────────────────
# Passed through to scripts/audit-settings/*.ps1 (see modules/audit-settings/main.tf).

variable "tenant_id" {
  description = "Entra ID tenant ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "App registration (application) ID with Compliance Administrator rights, used for certificate-based app-only auth to Security & Compliance PowerShell"
  type        = string
  sensitive   = true
}

variable "certificate_thumbprint" {
  description = "Thumbprint of the certificate (installed in Cert:\\CurrentUser\\My on the machine running terraform apply) used for app-only auth to Security & Compliance PowerShell"
  type        = string
  sensitive   = true
}

variable "organization" {
  description = "Tenant's *.onmicrosoft.com domain, required by Connect-IPPSSession -Organization"
  type        = string
}
