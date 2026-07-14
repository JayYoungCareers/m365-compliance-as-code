# ─── Dev Environment ──────────────────────────────────────────────────────────
# Values for non-production testing. DLP runs in audit-only mode.

environment = "dev"
location    = "eastus"

# ⚠️  Populate these — do NOT commit real tenant/subscription/app identifiers here.
# Real values live in environments/dev.local.tfvars (git-ignored) — pass both files to
# terraform: -var-file="environments/dev.tfvars" -var-file="environments/dev.local.tfvars"
tenant_id       = "" # see environments/dev.local.tfvars
subscription_id = "" # see environments/dev.local.tfvars
client_id       = "" # see environments/dev.local.tfvars
# client_secret → set via TF_VAR_client_secret (azurerm/azuread auth only). NOT assigned here:
# Terraform's precedence puts -var-file values ABOVE environment variables, so an explicit
# client_secret = "" in this file would silently override TF_VAR_client_secret.

# Certificate-based app-only auth for Security & Compliance PowerShell (DLP, labels,
# retention, audit). Cert is installed in Cert:\CurrentUser\My on this machine and its
# public key is uploaded to the App Registration above.
# certificate_thumbprint → set via TF_VAR_certificate_thumbprint, same reason as client_secret above.
organization = "" # see environments/dev.local.tfvars

dlp_mode         = "audit" # log-only in dev
dlp_notify_email = "grc-alerts-dev@yourcompany.com"

purview_account_name       = "purview-compliance-baseline"
log_analytics_workspace_id = "" # optional — set to enable Purview diagnostic export

retention_periods = {
  financial = 2555
  hr        = 2555
  legal     = 3650
  general   = 1095
}

tags = {
  managed_by  = "terraform"
  project     = "purview-compliance-baseline"
  environment = "dev"
  cost_center = "grc"
}
