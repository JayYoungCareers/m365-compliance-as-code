# ─── DLP Policies ─────────────────────────────────────────────────────────────
# Three policies covering PII, financial data, and health information.
# Mode is driven by the `mode` variable: "audit" (log only) or "block" (enforce).
#
# Like sensitivity-labels, there's no Terraform provider for Purview DLP — each policy is a
# terraform_data resource whose provisioners shell out to New/Set-DlpCompliancePolicy and
# New/Set-DlpComplianceRule via Security & Compliance PowerShell. See
# scripts/dlp-policies/*.ps1 for the actual cmdlets.

locals {
  state_dir = "${path.root}/.compliance-state/dlp-policies"
  dlp_mode  = var.mode == "block" ? "Enable" : "TestWithNotifications"
  severity  = { pii = "High", financial = "High", health = "Critical" }

  policies = {
    pii = {
      name    = "DLP-PII-Protection-${var.environment}"
      comment = "Prevents sharing of personally identifiable information externally."
      rule = {
        name           = "PII-SSN-CreditCard-Rule"
        priority       = 1
        access_scope   = "NotInOrganization"
        notify_message = "This content appears to contain PII and cannot be shared externally without approval."
        report_to      = [var.notify_email]
        severity       = local.severity.pii
        sensitive_info_types = [
          { name = "U.S. Social Security Number (SSN)", min_count = 1, confidence_level = "High" },
          { name = "Credit Card Number", min_count = 1, confidence_level = "High" },
          { name = "U.S. Individual Taxpayer Identification Number (ITIN)", min_count = 1, confidence_level = "Medium" },
        ]
        # Also catch content carrying the Highly Confidential / Confidential sensitivity labels
        label_ids = compact([
          lookup(var.label_ids, "HighlyConfidential", ""),
          lookup(var.label_ids, "Confidential", "")
        ])
      }
    }

    financial = {
      name    = "DLP-Financial-Data-${var.environment}"
      comment = "Protects financial records: ABA routing numbers, bank accounts, financial statements."
      rule = {
        name           = "Financial-Data-Rule"
        priority       = 1
        access_scope   = "NotInOrganization"
        notify_message = "Financial data detected. External sharing is restricted per policy DLP-FINANCIAL."
        report_to      = [var.notify_email]
        severity       = local.severity.financial
        sensitive_info_types = [
          { name = "ABA Routing Number", min_count = 1, confidence_level = "High" },
          { name = "U.S. Bank Account Number", min_count = 1, confidence_level = "High" },
          { name = "Credit Card Number", min_count = 5, confidence_level = "Medium" },
        ]
        label_ids = []
      }
    }

    health = {
      name    = "DLP-PHI-HIPAA-${var.environment}"
      comment = "HIPAA-aligned policy protecting protected health information (PHI)."
      rule = {
        name           = "PHI-Detection-Rule"
        priority       = 1
        access_scope   = "NotInOrganization"
        notify_message = "Health information (PHI) detected. Sharing externally violates HIPAA policy."
        report_to      = [var.notify_email]
        severity       = local.severity.health
        sensitive_info_types = [
          { name = "U.S. Health Insurance Claim Number", min_count = 1, confidence_level = "High" },
          { name = "International Classification of Diseases (ICD-9-CM)", min_count = 1, confidence_level = "Medium" },
          { name = "International Classification of Diseases (ICD-10-CM)", min_count = 1, confidence_level = "Medium" },
        ]
        label_ids = []
      }
    }
  }
}

resource "terraform_data" "policy" {
  for_each = local.policies

  input = {
    policy                 = merge(each.value, { mode = local.dlp_mode })
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${local.state_dir}/${each.key}.json"
    remove_script          = "${path.module}/../../scripts/dlp-policies/Remove-DlpPolicy.ps1"
  }

  triggers_replace = [jsonencode(merge(each.value, { mode = local.dlp_mode }))]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/dlp-policies/Set-DlpPolicy.ps1"

    environment = {
      POLICY_JSON     = jsonencode(self.input.policy)
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = self.input.remove_script

    environment = {
      POLICY_NAME     = self.input.policy.name
      RULE_NAME       = self.input.policy.rule.name
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }
}

data "local_file" "policy_state" {
  for_each = terraform_data.policy

  filename   = each.value.output.state_file
  depends_on = [terraform_data.policy]
}
