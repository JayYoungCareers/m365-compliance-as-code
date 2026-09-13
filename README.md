# m365-compliance-as-code

[![Terraform CI](https://github.com/JayYoungCareers/m365-compliance-as-code/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/JayYoungCareers/m365-compliance-as-code/actions/workflows/terraform-ci.yml)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Microsoft Purview](https://img.shields.io/badge/Microsoft%20Purview-Compliance-0078D4?logo=microsoft&logoColor=white)](https://learn.microsoft.com/en-us/purview/)
[![PowerShell](https://img.shields.io/badge/Security%20%26%20Compliance-PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/exchange/scc-powershell)

A Microsoft 365 / Purview data protection baseline — sensitivity labels, DLP, retention, and unified audit logging — defined as Terraform, versioned, reviewed in pull requests, and torn down with `terraform destroy`.

The interesting part is the part Terraform can't do on its own. **Microsoft ships no Terraform provider for the Purview Security & Compliance surface.** DLP policies, sensitivity labels, retention labels, and the unified audit log live in the Security & Compliance Center and are reachable only through `Connect-IPPSSession` PowerShell cmdlets. This repo is the hybrid that closes that gap without giving up the Terraform lifecycle.

---

## What gets deployed

**Sensitivity labels** — four-tier classification scheme, published org-wide by a single label policy.

| Label | Priority | Encryption | Content marking | Watermark |
|---|---|---|---|---|
| Public | 0 | — | — | — |
| Internal | 1 | — | ✓ | `INTERNAL` |
| Confidential | 2 | ✓ | ✓ | `CONFIDENTIAL` |
| Highly Confidential | 3 | ✓ | ✓ | `HIGHLY CONFIDENTIAL` |

**DLP policies** — three policies scoped to external sharing (`NotInOrganization`) across Exchange, SharePoint, OneDrive, and Teams.

| Policy | Detects | Severity |
|---|---|---|
| `DLP-PII-Protection` | SSN, credit card, ITIN — **plus** any content carrying the Confidential or Highly Confidential label | High |
| `DLP-Financial-Data` | ABA routing number, U.S. bank account number, credit card (≥5, medium confidence) | High |
| `DLP-PHI-HIPAA` | U.S. health insurance claim number, ICD-9-CM, ICD-10-CM | Critical |

Enforcement is one variable. `dlp_mode = "audit"` maps to `TestWithNotifications` (log and notify); `dlp_mode = "block"` maps to `Enable` with `BlockAccess` set. Dev defaults to audit.

The PII policy consumes label IDs emitted by the sensitivity-labels module, so classification and prevention are wired to each other rather than maintained as two independent lists.

**Retention** — four labels by data class, plus three location policies publishing general retention.

| Label | Duration | Declared as record |
|---|---|---|
| `Retain-Financial` | 2,555 days (~7 years) | — |
| `Retain-HR` | 2,555 days (~7 years) | — |
| `Retain-Legal` | 3,650 days (~10 years) | ✓ |
| `Retain-General` | 1,095 days (~3 years) | — |

All use `KeepAndDelete` triggered on `ModificationAgeInDays`. General retention is published to Exchange, to SharePoint + OneDrive, and to Teams channel + chat.

**Audit** — enables the tenant-wide unified audit log, and optionally forwards Purview account activity (`DataSensitivityLogEvent`, `ScanStatusLogEvent`, `Security`) to a Log Analytics workspace for SIEM ingestion.

**Azure resources** — a resource group and an Azure Purview account with a system-assigned identity, for data map, scanning, and classification of Azure data sources.

---

## How the Terraform/PowerShell hybrid works

Native ARM resources (`azurerm_resource_group`, `azurerm_purview_account`, `azurerm_monitor_diagnostic_setting`) are ordinary `azurerm` provider resources.

Everything in the Security & Compliance Center is modeled as a `terraform_data` resource with `local-exec` provisioners that shell out to the corresponding cmdlets:

```
sensitivity-labels  →  New-Label / Set-Label, New-LabelPolicy
dlp-policies        →  New-DlpCompliancePolicy, New-DlpComplianceRule
retention-policies  →  New-ComplianceTag, New-RetentionCompliancePolicy
audit-settings      →  Set-AdminAuditLogConfig
```

Four design decisions make that behave like real infrastructure-as-code rather than a shell script in a trench coat:

**`triggers_replace` on a hash of the config.** Each resource sets `triggers_replace = [jsonencode(config)]`, so changing a label's color or a retention duration produces a genuine replace in `terraform plan`. You see intent before anything is mutated.

**Destroy-time provisioners.** Every module ships a matching `Remove-*.ps1` wired to a `when = destroy` provisioner, so `terraform destroy` actually removes the policies from the tenant. The removal script path is captured into `input` at plan time, because destroy-time provisioners can't reference `path.module`.

**IDs are read back, not guessed.** Each `Set-*.ps1` writes the created object's ID to `.compliance-state/<module>/<name>.json`. A `data "local_file"` reads it back, which is what lets module outputs be consumed downstream — the DLP module's label conditions come from the sensitivity-labels module's real, tenant-assigned label IDs.

**Idempotent scripts.** Every script checks `Get-*` first and branches to `Set-*` or `New-*`, so re-running `apply` converges rather than erroring or duplicating.

### Authentication: one app registration, two auth methods

This trips people up, so it is worth being explicit. The `azurerm` and `azuread` providers authenticate with a **client secret**. Security & Compliance PowerShell authenticates with a **certificate** — `Connect-IPPSSession` has no client-secret mode for unattended app-only use. Same App Registration, two credentials.

| Path | Credential | Required grant |
|---|---|---|
| `azurerm` / `azuread` providers | `client_secret` (via `TF_VAR_client_secret`) | Azure RBAC on the subscription |
| `Connect-IPPSSession` | Certificate in `Cert:\CurrentUser\My`, thumbprint via `TF_VAR_certificate_thumbprint` | **Compliance Administrator** role group in Microsoft 365 |

The certificate's public key must be uploaded to the App Registration.

---

## Requirements

- **Terraform ≥ 1.5.0** (CI pins 1.15.8). `terraform_data` requires ≥ 1.4.
- Providers: `azurerm ~> 3.90`, `azuread ~> 2.47`, `local ~> 2.5`.
- **Windows with Windows PowerShell.** The provisioners invoke `PowerShell` and the certificate is read from `Cert:\CurrentUser\My`. This is not portable to Linux runners today.
- `ExchangeOnlineManagement` module: `Install-Module ExchangeOnlineManagement -Scope CurrentUser`
- An App Registration with the Azure RBAC and Compliance Administrator grants above.

## Usage

Real tenant identifiers never land in the repo. `environments/dev.tfvars` carries only non-secret shape; the actual values go in `environments/dev.local.tfvars`, which `.gitignore` excludes via `*.local.tfvars`.

```powershell
# Secrets by environment variable — never in a tfvars file.
$env:TF_VAR_client_secret          = "<app registration client secret>"
$env:TF_VAR_certificate_thumbprint = "<thumbprint of the cert in Cert:\CurrentUser\My>"

terraform init

terraform plan `
  -var-file="environments/dev.tfvars" `
  -var-file="environments/dev.local.tfvars"

terraform apply `
  -var-file="environments/dev.tfvars" `
  -var-file="environments/dev.local.tfvars"
```

`client_secret` and `certificate_thumbprint` are deliberately **not** assigned in `dev.tfvars`. Terraform's precedence puts `-var-file` values above environment variables, so an empty assignment there would silently shadow the `TF_VAR_` value.

Tear down with `terraform destroy` and the same `-var-file` pair — the destroy provisioners remove the policies from the tenant.

## Repository layout

```
main.tf, variables.tf, providers.tf, outputs.tf   Root: Azure resources + module wiring
environments/dev.tfvars                           Non-secret dev values
modules/
  sensitivity-labels/    4 labels + org-wide publish policy
  dlp-policies/          3 DLP policies, audit or block
  retention-policies/    4 retention labels + 3 location policies
  audit-settings/        Unified audit log + optional Log Analytics export
scripts/
  common/                Connect-IPPSSession auth, state read/write helpers
  <module>/Set-*.ps1     Idempotent create-or-update
  <module>/Remove-*.ps1  Destroy-time teardown
.github/workflows/       Terraform CI
```

## CI

`terraform-ci.yml` runs on push and pull request to `main`: `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate`.

It deliberately stops short of `plan` and `apply`. Both need a Windows runner with the compliance certificate installed and `ExchangeOnlineManagement` present — a self-hosted runner concern, not something a stock hosted runner can do. Wiring up a credential-less `plan` that would fail for the wrong reason would be worse than not having one.

## Known limits

Stated plainly, because a compliance baseline that oversells itself is the wrong kind of artifact.

- **`.compliance-state/` is a cache, not state.** It holds IDs read back from the tenant so modules can reference each other. The tenant remains source of truth. A policy edited by hand in the Purview portal will not be detected as drift.
- **No drift detection for the PowerShell-managed objects.** `triggers_replace` fires on changes to the Terraform config, not on changes made in the tenant.
- **Windows-only**, per the requirements above.
- **Local state backend.** `terraform.tfstate` is git-ignored; an `azurerm` remote backend block sits commented in `providers.tf` ready to swap in.
- **Dev only in-repo.** `environments/prod.tfvars` is git-ignored by design; production values are expected to come from a CI/CD secret store.
- **One volatile surface.** The sensitivity-label-as-DLP-condition syntax in `Set-DlpPolicy.ps1` follows Microsoft Learn's documented shape, but it is among the more frequently revised corners of the Compliance PowerShell API. Verify against `Get-Command New-DlpComplianceRule -Syntax` on your installed module version.

---

Built by [Jay Young](https://github.com/JayYoungCareers). See also [cgep-labs](https://github.com/JayYoungCareers/cgep-labs) — NIST 800-53 controls implemented in Terraform and enforced by OPA/Rego policy gates in CI.
# m365-compliance-as-code
Infrastructure-as-code framework for deploying and managing Microsoft 365 compliance policies across dev and prod environments via Terraform and GitHub Actions CI/CD.
