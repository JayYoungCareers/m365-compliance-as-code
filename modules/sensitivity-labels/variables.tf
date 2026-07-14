variable "labels" {
  description = "Sensitivity label definitions"
  type = list(object({
    name           = string
    display_name   = string
    description    = string
    tooltip        = string
    priority       = number
    color          = string
    encrypt        = bool
    mark_content   = bool
    watermark_text = optional(string, "")
  }))
}

variable "environment" {
  type = string
}

# ─── Security & Compliance PowerShell auth ────────────────────────────────────
# Passed through to scripts/sensitivity-labels/*.ps1 (see modules/sensitivity-labels/main.tf).

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
