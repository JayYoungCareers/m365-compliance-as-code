terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # terraform_data is the built-in "terraform" provider — bundled with Terraform core
  # since v1.4, no required_providers entry needed.

  # Local backend for now — state lives in terraform.tfstate (already git-ignored).
  # Swap back to a real remote backend once one exists; see the commented block below.
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "purview-compliance/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

provider "azuread" {
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}

# NOTE: there is no Terraform provider for Microsoft Purview's Security & Compliance
# features (DLP, sensitivity labels, retention, unified audit log) — they're configured by
# the compliance modules shelling out to Security & Compliance PowerShell instead (see
# scripts/ and each module's main.tf). That path authenticates separately via
# certificate-based app-only auth (var.certificate_thumbprint), not through a Terraform
# provider block, because Connect-IPPSSession has no client-secret auth mode for unattended
# use. The same App Registration (var.client_id) is used for both, granted Azure RBAC roles
# here and added to the Compliance Administrator role group in Microsoft 365 for the
# PowerShell path.
