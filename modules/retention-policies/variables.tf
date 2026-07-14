variable "retention_periods" {
  type = object({
    financial = number
    hr        = number
    legal     = number
    general   = number
  })
}

variable "environment" {
  type = string
}

# ─── Security & Compliance PowerShell auth ────────────────────────────────────
# Passed through to scripts/retention-policies/*.ps1 (see modules/retention-policies/main.tf).

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
