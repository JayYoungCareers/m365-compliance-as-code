# ─── Sensitivity Labels ───────────────────────────────────────────────────────
# There is no Terraform provider for Microsoft Purview sensitivity labels — they live in
# the Security & Compliance Center and are only manageable via the New-Label / Set-Label /
# New-LabelPolicy cmdlets (ExchangeOnlineManagement's Connect-IPPSSession). Each label is
# modeled as a terraform_data resource whose local-exec provisioners shell out to those
# cmdlets, so `terraform plan` still shows create/replace intent and `terraform destroy`
# still tears things down — see scripts/sensitivity-labels/*.ps1 for the actual cmdlets.

locals {
  state_dir = "${path.root}/.compliance-state/sensitivity-labels"
}

resource "terraform_data" "label" {
  for_each = { for l in var.labels : l.name => l }

  input = {
    label                  = each.value
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${local.state_dir}/${each.key}.json"
    # Destroy-time provisioners can't reference path.module directly (deprecated/unreliable —
    # only `self` is guaranteed available), so the resolved path is captured here instead.
    remove_script = "${path.module}/../../scripts/sensitivity-labels/Remove-SensitivityLabel.ps1"
  }

  triggers_replace = [jsonencode(each.value)]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/sensitivity-labels/Set-SensitivityLabel.ps1"

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

# ─── Label Policy ─────────────────────────────────────────────────────────────
# Publishes all labels to the entire organization.

resource "terraform_data" "label_policy" {
  input = {
    policy = {
      name        = "Org-Wide-Sensitivity-Label-Policy-${var.environment}"
      description = "Publishes all baseline sensitivity labels to all users."
      mandatory   = false
      label_names = [for l in var.labels : l.name]
    }
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    certificate_thumbprint = var.certificate_thumbprint
    organization           = var.organization
    state_file             = "${local.state_dir}/_policy.json"
    remove_script          = "${path.module}/../../scripts/sensitivity-labels/Remove-LabelPolicy.ps1"
  }

  triggers_replace = [jsonencode([for l in var.labels : l.name])]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/../../scripts/sensitivity-labels/Set-LabelPolicy.ps1"

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
      TENANT_ID       = self.input.tenant_id
      APP_ID          = self.input.client_id
      CERT_THUMBPRINT = self.input.certificate_thumbprint
      ORGANIZATION    = self.input.organization
      STATE_FILE      = self.input.state_file
    }
  }

  depends_on = [terraform_data.label]
}

data "local_file" "label_policy_state" {
  filename   = terraform_data.label_policy.output.state_file
  depends_on = [terraform_data.label_policy]
}
