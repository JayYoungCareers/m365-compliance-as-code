# ─── Retention Policies ───────────────────────────────────────────────────────
# Creates retention labels per data class, then policies that publish the general-retention
# label to SharePoint/OneDrive, Exchange, and Teams.
#
# No Terraform provider covers Purview retention labels/policies either — each is a
# terraform_data resource whose provisioners shell out to New/Set-ComplianceTag and
# New/Set-RetentionCompliancePolicy via Security & Compliance PowerShell. See
# scripts/retention-policies/*.ps1 for the actual cmdlets.

locals {
  state_dir = "${path.root}/.compliance-state/retention-policies"

  labels = {
    financial = {
      name               = "Retain-Financial-${var.environment}"
      comment            = "Retain financial records for ${var.retention_periods.financial} days (~7 years)."
      retention_duration = var.retention_periods.financial
      retention_action   = "KeepAndDelete"
      retention_type     = "ModificationAgeInDays"
      is_record          = false
    }
    hr = {
      name               = "Retain-HR-${var.environment}"
      comment            = "Retain HR records for ${var.retention_periods.hr} days (~7 years)."
      retention_duration = var.retention_periods.hr
      retention_action   = "KeepAndDelete"
      retention_type     = "ModificationAgeInDays"
      is_record          = false
    }
    legal = {
      name               = "Retain-Legal-${var.environment}"
      comment            = "Retain legal documents for ${var.retention_periods.legal} days (~10 years)."
      retention_duration = var.retention_periods.legal
      retention_action   = "KeepAndDelete"
      retention_type     = "ModificationAgeInDays"
      is_record          = true # legal docs declared as records
    }
    general = {
      name               = "Retain-General-${var.environment}"
      comment            = "General retention for ${var.retention_periods.general} days (~3 years)."
      retention_duration = var.retention_periods.general
      retention_action   = "KeepAndDelete"
      retention_type     = "ModificationAgeInDays"
      is_record          = false
    }
  }

  # General retention is applied org-wide across these three location policies.
  policies = {
    exchange = {
      name       = "RetentionPolicy-Exchange-General-${var.environment}"
      comment    = "Applies general retention to all Exchange mailboxes."
      rule_name  = "RetentionRule-Exchange-General-${var.environment}"
      label_name = local.labels.general.name
      locations  = { exchange = true, sharepoint = false, onedrive = false, teams_channel = false, teams_chat = false }
    }
    sharepoint = {
      name       = "RetentionPolicy-SharePoint-General-${var.environment}"
      comment    = "Applies general retention to all SharePoint sites and OneDrive accounts."
      rule_name  = "RetentionRule-SharePoint-General-${var.environment}"
      label_name = local.labels.general.name
      locations  = { exchange = false, sharepoint = true, onedrive = true, teams_channel = false, teams_chat = false }
    }
    teams = {
      name       = "RetentionPolicy-Teams-${var.environment}"
      comment    = "Retains Teams channel and chat messages."
      rule_name  = "RetentionRule-Teams-General-${var.environment}"
      label_name = local.labels.general.name
      locations  = { exchange = false, sharepoint = false, onedrive = false, teams_channel = true, teams_chat = true }
    }
  }
}

resource "terraform_data" "label" {
  for_each = local.labels

  input = {
    label                  = each.value
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${local.state_dir}/label-${each.key}.json"
    remove_script          = "${path.module}/../../scripts/retention-policies/Remove-RetentionLabel.ps1"
  }

  triggers_replace = [jsonencode(each.value)]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/retention-policies/Set-RetentionLabel.ps1"

    environment = {
      LABEL_JSON      = jsonencode(self.input.label)
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
      LABEL_NAME      = self.input.label.name
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }
}

data "local_file" "label_state" {
  for_each = terraform_data.label

  filename   = each.value.output.state_file
  depends_on = [terraform_data.label]
}

resource "terraform_data" "policy" {
  for_each = local.policies

  input = {
    policy                 = each.value
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${local.state_dir}/policy-${each.key}.json"
    remove_script          = "${path.module}/../../scripts/retention-policies/Remove-RetentionPolicy.ps1"
  }

  triggers_replace = [jsonencode(each.value)]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/retention-policies/Set-RetentionPolicy.ps1"

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
      RULE_NAME       = self.input.policy.rule_name
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }

  depends_on = [terraform_data.label]
}

data "local_file" "policy_state" {
  for_each = terraform_data.policy

  filename   = each.value.output.state_file
  depends_on = [terraform_data.policy]
}
