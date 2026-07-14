# ─── Authentication ───────────────────────────────────────────────────────────

variable "tenant_id" {
  description = "Azure / Entra ID tenant ID"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure subscription ID (used for resource group and Purview account)"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Service principal / app registration client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Service principal client secret (used for azurerm/azuread provider auth only)"
  type        = string
  sensitive   = true
}

# ─── Security & Compliance PowerShell auth ────────────────────────────────────
# There is no Terraform provider for Purview DLP / sensitivity labels / retention / audit —
# the compliance modules shell out to Security & Compliance PowerShell instead, which
# requires certificate-based app-only auth (client secrets aren't supported for unattended
# Connect-IPPSSession). See scripts/common/Connect-Compliance.ps1.

variable "certificate_thumbprint" {
  description = "Thumbprint of the certificate (installed in Cert:\\CurrentUser\\My on the machine running terraform apply) for the App Registration used to authenticate to Security & Compliance PowerShell. The same App Registration as client_id, granted the Compliance Administrator role."
  type        = string
  sensitive   = true
}

variable "organization" {
  description = "Tenant's *.onmicrosoft.com domain, required by Connect-IPPSSession -Organization"
  type        = string
}

# ─── Environment ──────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "location" {
  description = "Azure region for infrastructure resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags applied to all Azure resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    project     = "purview-compliance-baseline"
    cost_center = "grc"
  }
}

# ─── Sensitivity Labels ───────────────────────────────────────────────────────

variable "sensitivity_labels" {
  description = "List of sensitivity label definitions"
  type = list(object({
    name           = string
    display_name   = string
    description    = string
    tooltip        = string
    priority       = number
    color          = string # hex color shown in Office apps
    encrypt        = bool
    mark_content   = bool
    watermark_text = optional(string, "")
  }))
  default = [
    {
      name         = "Public"
      display_name = "Public"
      description  = "Data approved for unrestricted public distribution."
      tooltip      = "Apply to content that is cleared for public release."
      priority     = 0
      color        = "#33CC33"
      encrypt      = false
      mark_content = false
    },
    {
      name           = "Internal"
      display_name   = "Internal"
      description    = "Non-sensitive internal business data."
      tooltip        = "Apply to general internal communication and documents."
      priority       = 1
      color          = "#0070C0"
      encrypt        = false
      mark_content   = true
      watermark_text = "INTERNAL"
    },
    {
      name           = "Confidential"
      display_name   = "Confidential"
      description    = "Sensitive business data. Unauthorized disclosure causes harm."
      tooltip        = "Apply to contracts, financials, and HR data."
      priority       = 2
      color          = "#FF9900"
      encrypt        = true
      mark_content   = true
      watermark_text = "CONFIDENTIAL"
    },
    {
      name           = "HighlyConfidential"
      display_name   = "Highly Confidential"
      description    = "Regulated or secret data — PII, PCI, PHI, trade secrets."
      tooltip        = "Apply to regulated data. Encryption and DLP enforced."
      priority       = 3
      color          = "#FF0000"
      encrypt        = true
      mark_content   = true
      watermark_text = "HIGHLY CONFIDENTIAL"
    }
  ]
}

# ─── DLP ──────────────────────────────────────────────────────────────────────

variable "dlp_mode" {
  description = "DLP enforcement mode: 'audit' logs violations, 'block' enforces them"
  type        = string
  default     = "audit"

  validation {
    condition     = contains(["audit", "block"], var.dlp_mode)
    error_message = "dlp_mode must be 'audit' or 'block'."
  }
}

variable "dlp_notify_email" {
  description = "Email address for DLP incident notifications"
  type        = string
}

# ─── Retention ────────────────────────────────────────────────────────────────

variable "retention_periods" {
  description = "Retention durations in days per data class"
  type = object({
    financial = number
    hr        = number
    legal     = number
    general   = number
  })
  default = {
    financial = 2555 # 7 years
    hr        = 2555 # 7 years
    legal     = 3650 # 10 years
    general   = 1095 # 3 years
  }
}

# ─── Purview Account (Azure Data Governance) ──────────────────────────────────

variable "purview_account_name" {
  description = "Name of the Azure Purview (data governance) account"
  type        = string
  default     = "purview-compliance-baseline"
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of an existing Log Analytics workspace for Purview audit export (leave blank to skip)"
  type        = string
  default     = ""
}
