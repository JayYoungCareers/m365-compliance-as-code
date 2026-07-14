# ─── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "compliance" {
  name     = "rg-purview-compliance-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ─── Azure Purview Account (Data Governance) ──────────────────────────────────
# Provides data map, scanning, and classification for Azure data sources

resource "azurerm_purview_account" "main" {
  name                = "${var.purview_account_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.compliance.name
  location            = azurerm_resource_group.compliance.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ─── Modules ──────────────────────────────────────────────────────────────────

locals {
  # Shared Security & Compliance PowerShell auth, passed to every compliance module.
  compliance_auth = {
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
  }
}

module "sensitivity_labels" {
  source = "./modules/sensitivity-labels"

  labels      = var.sensitivity_labels
  environment = var.environment

  tenant_id              = local.compliance_auth.tenant_id
  client_id              = local.compliance_auth.client_id
  certificate_thumbprint = local.compliance_auth.certificate_thumbprint
  organization           = local.compliance_auth.organization
}

module "dlp_policies" {
  source = "./modules/dlp-policies"

  mode         = var.dlp_mode
  notify_email = var.dlp_notify_email
  environment  = var.environment

  # DLP rules will automatically target Highly Confidential and Confidential labels
  label_ids = module.sensitivity_labels.label_ids

  tenant_id              = local.compliance_auth.tenant_id
  client_id              = local.compliance_auth.client_id
  certificate_thumbprint = local.compliance_auth.certificate_thumbprint
  organization           = local.compliance_auth.organization

  depends_on = [module.sensitivity_labels]
}

module "retention_policies" {
  source = "./modules/retention-policies"

  retention_periods = var.retention_periods
  environment       = var.environment

  tenant_id              = local.compliance_auth.tenant_id
  client_id              = local.compliance_auth.client_id
  certificate_thumbprint = local.compliance_auth.certificate_thumbprint
  organization           = local.compliance_auth.organization
}

module "audit_settings" {
  source = "./modules/audit-settings"

  environment = var.environment

  purview_account_id         = azurerm_purview_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tenant_id              = local.compliance_auth.tenant_id
  client_id              = local.compliance_auth.client_id
  certificate_thumbprint = local.compliance_auth.certificate_thumbprint
  organization           = local.compliance_auth.organization
}
