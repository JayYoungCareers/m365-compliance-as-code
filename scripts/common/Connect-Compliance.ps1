# Dot-sourced helper for Security & Compliance PowerShell (Purview compliance cmdlets).
# There is no Terraform provider for DLP / sensitivity labels / retention / audit config today —
# those live in the Security & Compliance Center and are only reachable via the
# ExchangeOnlineManagement module's Connect-IPPSSession. Terraform's terraform_data +
# local-exec provisioners shell out to these cmdlets so the compliance modules stay
# declarative and lifecycle-managed (create on apply, clean up on destroy) even though
# the actual mutation happens over Remote PowerShell rather than an ARM/Graph provider.
#
# Auth is certificate-based app-only (the modern, non-interactive method Microsoft
# requires for unattended Security & Compliance PowerShell sessions) using the same
# App Registration as the rest of this project, with a certificate installed in
# Cert:\CurrentUser\My on the machine running `terraform apply`.

function Connect-CompliancePS {
    param(
        [Parameter(Mandatory)] [string] $TenantId,
        [Parameter(Mandatory)] [string] $AppId,
        [Parameter(Mandatory)] [string] $CertificateThumbprint,
        [Parameter(Mandatory)] [string] $Organization
    )

    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw "ExchangeOnlineManagement module not found. Install with: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    $activeSession = Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.TokenStatus -eq "Active" -and $_.Organization -eq $Organization }

    if ($activeSession) {
        return
    }

    Connect-IPPSSession `
        -AppId $AppId `
        -CertificateThumbprint $CertificateThumbprint `
        -Organization $Organization `
        -ShowBanner:$false
}

function Disconnect-CompliancePS {
    Get-ConnectionInformation -ErrorAction SilentlyContinue | ForEach-Object {
        Disconnect-ExchangeOnline -ConnectionId $_.ConnectionId -Confirm:$false -ErrorAction SilentlyContinue
    }
}

function Write-ComplianceState {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [hashtable] $State
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding utf8
}

function Remove-ComplianceState {
    param([Parameter(Mandatory)] [string] $Path)

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
    }
}
