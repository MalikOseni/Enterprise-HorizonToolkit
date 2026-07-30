[![CI](https://github.com/MalikOseni/Enterprise-HorizonToolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/MalikOseni/Enterprise-HorizonToolkit/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Enterprise-HorizonToolkit)](https://www.powershellgallery.com/packages/Enterprise-HorizonToolkit)

# Enterprise-HorizonToolkit

> A PowerShell module for VMware Horizon administrators — real-time session
> health, pool monitoring, proactive user messaging, and safely guarded machine
> remediation.

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/MalikOseni/Enterprise-HorizonToolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Why this exists

The Horizon Administrator console reflects a cached, delayed view of your
estate. This toolkit talks directly to the Horizon API and returns accurate,
structured data immediately — no refresh, no lag.

It is designed for engineers who manage Horizon environments day to day and
need reliable automation without writing bespoke scripts for every task.

---

## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 5.1 or later |
| VMware.VimAutomation.HorizonView | 13.x or later |
| VMware Horizon Connection Server | 8.x or later |
| OS | Windows (PowerShell 5.1) or Windows / Linux / macOS (PowerShell 7+) |

> **VMware licensing:** This module requires VMware Horizon PowerCLI, which
> must be independently licensed and installed. This module does not include
> or distribute any VMware binaries. See the
> [VMware PowerCLI documentation](https://developer.vmware.com/powercli) for
> installation instructions.

---

## Installation

### From the PowerShell Gallery (recommended)

```powershell
Install-Module -Name Enterprise-HorizonToolkit -Scope CurrentUser
```

### From source

```powershell
git clone https://github.com/MalikOseni/Enterprise-HorizonToolkit.git
Import-Module .\Enterprise-HorizonToolkit\Enterprise-HorizonToolkit.psd1 -Force
```

### Prerequisites

```powershell
# Install VMware Horizon PowerCLI (required dependency — not included)
Install-Module -Name VMware.VimAutomation.HorizonView -Scope CurrentUser
```

---

## Quick start

```powershell
# 1. Import the module
Import-Module Enterprise-HorizonToolkit

# 2. Connect to your Horizon environment
Connect-Horizon -Credential (Get-Credential)

# 3. Check pool health across the estate
Get-HorizonPoolHealth | Format-Table -AutoSize

# 4. Find sessions disconnected for more than 6 hours
Get-HorizonDisconnectedSessions -HoursDisconnected 6 |
    Format-Table UserName, MachineName, DesktopPool, HoursDisconnected
```

---

## Configuration

Copy the example configuration and populate it for your environment:

```powershell
Copy-Item .\Config\ToolkitConfig.example.psd1 .\Config\ToolkitConfig.psd1
```

Open `Config\ToolkitConfig.psd1` and set your values:

```powershell
@{
    # One or more Horizon Connection Server FQDNs
    ConnectionServers = @('horizon-cs01.yourdomain.local')

    # Logging
    LogPath  = 'C:\Logs\HorizonToolkit'
    LogLevel = 'Information'   # Information | Warning | Error

    # Default thresholds (overridable per cmdlet)
    Thresholds = @{
        IdleMinutes        = 120
        DisconnectedHours  = 6
    }

    # Pools and users exempt from automated remediation
    Exclusions = @{
        Pools = @()
        Users = @()
    }
}
```

> **Important:** `Config\ToolkitConfig.psd1` is excluded from source control
> by `.gitignore`. Never commit a populated configuration file. Use
> `ToolkitConfig.example.psd1` as the version-controlled template.

---

## Cmdlet reference

### Connection

| Cmdlet | Description |
|---|---|
| `Connect-Horizon` | Authenticates and caches the Horizon connection for use by all other cmdlets |

```powershell
# Interactive — prompts for credentials
Connect-Horizon -Credential (Get-Credential)

# Unattended — load from encrypted credential file created under the service account
$Credential = Import-Clixml -Path 'C:\Service\horizon-credential.xml'
Connect-Horizon -Credential $Credential
```

---

### Session reporting

| Cmdlet | Description |
|---|---|
| `Get-HorizonSessions` | Returns all active sessions with full metadata |
| `Get-HorizonIdleSessions` | Returns sessions exceeding the idle threshold |
| `Get-HorizonDisconnectedSessions` | Returns sessions disconnected beyond the threshold |
| `Get-HorizonFailedSessions` | Returns sessions in an error or failed state |

```powershell
# All sessions
Get-HorizonSessions

# Filter by machine
Get-HorizonSessions -MachineName 'VDI-001'

# Sessions idle for more than 2 hours
Get-HorizonIdleSessions -IdleThresholdMinutes 120

# Sessions disconnected for more than 6 hours
Get-HorizonDisconnectedSessions -HoursDisconnected 6

# Failed sessions
Get-HorizonFailedSessions | Format-Table UserName, MachineName, SessionState
```

---

### Health reporting

| Cmdlet | Description |
|---|---|
| `Get-HorizonMachineHealth` | Returns per-machine health objects including state, status, and pool |
| `Get-HorizonPoolHealth` | Aggregates machine health into pool-level summaries |

```powershell
# Full estate health
Get-HorizonMachineHealth

# Critical machines only
Get-HorizonMachineHealth | Where-Object HealthStatus -eq 'Critical'

# Pool health summary
Get-HorizonPoolHealth | Format-Table -AutoSize

# Pools with issues
Get-HorizonPoolHealth |
    Where-Object OverallHealth -ne 'Healthy' |
    Format-Table DesktopPool, TotalMachines, CriticalMachines, OverallHealth -AutoSize

# Specific pool
Get-HorizonPoolHealth -DesktopPool 'Pool-Name'
```

---

### Remediation

All remediation cmdlets require `-Execute` to take any action. Without it they
return a plan object showing exactly what would happen — always review the plan
before executing.

#### Send-HorizonSessionMessage

Sends a popup message to a connected session. Supports `INFO`, `WARNING`, and
`ERROR` message types.

```powershell
# Dry run — returns plan, no message sent
Send-HorizonSessionMessage `
    -MachineName 'VDI-001' `
    -Message 'Planned maintenance begins at 19:00. Please save your work.'

# Send with confirmation prompt
Send-HorizonSessionMessage `
    -MachineName 'VDI-001' `
    -Message 'Planned maintenance begins at 19:00. Please save your work.' `
    -MessageType WARNING `
    -Execute

# Send without confirmation prompt (bulk use — see bulk operations below)
Send-HorizonSessionMessage `
    -MachineName 'VDI-001' `
    -Message 'Planned maintenance begins at 19:00. Please save your work.' `
    -MessageType WARNING `
    -Execute `
    -Confirm:$false
```

#### Restart-HorizonMachine

Restarts a Horizon machine after enforcing guard checks. The cmdlet refuses to
proceed if the machine has connected or transitional sessions, recently
disconnected sessions, excluded users or pools, or failed sessions (unless
`-IncludeFailedSessions` is supplied). It also verifies that the installed
PowerCLI version exposes `Machine_Restart` before making the API call.

```powershell
# Dry run — returns plan, no restart occurs
Restart-HorizonMachine -MachineName 'VDI-001' -MinimumDisconnectedHours 6

# Preview with WhatIf
Restart-HorizonMachine -MachineName 'VDI-001' -MinimumDisconnectedHours 6 -Execute -WhatIf

# Execute with confirmation prompt
Restart-HorizonMachine -MachineName 'VDI-001' -MinimumDisconnectedHours 6 -Execute

# Execute without prompt (bulk use — see bulk operations below)
Restart-HorizonMachine -MachineName 'VDI-001' -MinimumDisconnectedHours 6 -Execute -Confirm:$false
```

---

### Bulk operations

Always perform a dry run before executing bulk operations.

```powershell
# --- Dry run first: preview all qualifying machines ---
Get-HorizonDisconnectedSessions |
    Where-Object { $_.HoursDisconnected -ge 6 } |
    ForEach-Object {
        Restart-HorizonMachine `
            -MachineName $_.MachineName `
            -MinimumDisconnectedHours 6
    }

# --- Execute once the plan looks correct ---
Get-HorizonDisconnectedSessions |
    Where-Object { $_.HoursDisconnected -ge 6 } |
    ForEach-Object {
        Restart-HorizonMachine `
            -MachineName $_.MachineName `
            -MinimumDisconnectedHours 6 `
            -Execute `
            -Confirm:$false
    }

# --- Scope to a specific pool ---
Get-HorizonDisconnectedSessions |
    Where-Object { $_.HoursDisconnected -ge 6 -and $_.DesktopPool -eq 'Pool-Name' } |
    ForEach-Object {
        Restart-HorizonMachine `
            -MachineName $_.MachineName `
            -MinimumDisconnectedHours 6 `
            -Execute `
            -Confirm:$false
    }

# --- Message all connected users before maintenance ---
$Message = 'Planned maintenance begins at 19:00. Please save and close your work.'

Get-HorizonSessions |
    Where-Object SessionState -eq 'CONNECTED' |
    ForEach-Object {
        Send-HorizonSessionMessage `
            -MachineName $_.MachineName `
            -Message $Message `
            -MessageType WARNING `
            -Execute `
            -Confirm:$false
    }

# --- Capture results and export for audit ---
$Results = @(
    Get-HorizonDisconnectedSessions |
        Where-Object { $_.HoursDisconnected -ge 6 } |
        ForEach-Object {
            Restart-HorizonMachine `
                -MachineName $_.MachineName `
                -MinimumDisconnectedHours 6 `
                -Execute `
                -Confirm:$false
        }
)

$Results | Export-Csv `
    -Path ".\RestartAudit_$(Get-Date -Format 'yyyyMMdd_HHmm').csv" `
    -NoTypeInformation

Write-Host "$($Results.Count) machine(s) restarted."
```

---

### Report export

```powershell
# Export pool health to CSV
Get-HorizonPoolHealth |
    Export-Csv -Path '.\PoolHealth.csv' -NoTypeInformation

# Export disconnected sessions to JSON
Get-HorizonDisconnectedSessions |
    ConvertTo-Json |
    Out-File '.\DisconnectedSessions.json'
```

---

## Safety model

Every remediation cmdlet is built around the same pattern:

1. **Plan first.** Without `-Execute`, the cmdlet returns a plan object
   describing exactly what it would do. Review it.
2. **Guard checks.** Before any action, the cmdlet validates the target against
   a set of safety conditions. If any check fails, it throws a descriptive
   error and takes no action.
3. **ShouldProcess.** All destructive cmdlets implement PowerShell's standard
   `-WhatIf` and `-Confirm` parameters.
4. **Structured logging.** Every cmdlet emits structured log entries at
   Information level for normal progress and Warning level for any action taken.

### What this module does not do

This module deliberately omits the following. These actions require additional
operational approval and safety controls beyond what is implemented here:

- Force log off sessions
- Force power off virtual machines
- Bulk-restart machines without per-machine guard checks
- Modify pool configuration or assignment

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `Get-HorizonService` not recognised | Module not loaded — run `Import-Module Enterprise-HorizonToolkit -Force` |
| `.Count` error under `StrictMode` | Known PowerShell behaviour — raise an issue with the output of `$Error[0].InvocationInfo \| Format-List *` |
| `Property not found` on session object | PowerCLI version mismatch — run `Get-Member` on the object to see actual property names |
| `Cannot find overload for Machine_Restart` | PowerCLI version does not expose this method — upgrade to 13.x or later |
| Credential decrypt failure | CLIXML was created under a different account — recreate it under the account that runs the module |
| GUI shows different state to toolkit | The Horizon Administrator console lags real-time API state — trust the toolkit output |

```powershell
# Get the exact failing line for any error
$Error[0].InvocationInfo | Format-List *

# Inspect actual property names on a session object
Get-HorizonSessions |
    Select-Object -First 1 |
    Get-Member -MemberType Properties

# Inspect nested properties
Get-HorizonSessions |
    Select-Object -First 1 |
    Select-Object -ExpandProperty <PropertyName> |
    Get-Member -MemberType Properties
```

---

## Project structure

```
Enterprise-HorizonToolkit/
├── Public/                  # Supported user-facing cmdlets
├── Private/                 # Internal helpers (connection, query, logging)
├── Config/
│   ├── ToolkitConfig.example.psd1   # Version-controlled template
│   └── ToolkitConfig.psd1           # Your local config — excluded from git
├── Enterprise-HorizonToolkit.psd1   # Module manifest
├── Enterprise-HorizonToolkit.psm1   # Module root
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## Roadmap

- [x] Guest OS layer — `Invoke-HorizonGuestCleanup`, `Stop-HorizonGuestProcess`,
      `Get-HorizonGuestDiagnostic` (via PowerShell remoting over `MachineDNS`)
- [ ] HTML health report export for client-facing weekly summaries
- [ ] Pester test suite
- [x] GitHub Actions CI — ScriptAnalyzer gate on every push to `main`
- [ ] Scheduled task wrapper scripts for automated daily health checks
- [ ] Prometheus metrics endpoint
- [ ] PowerShell 7 cross-platform validation

---

# Contributing

Thank you for your interest in contributing to Enterprise-HorizonToolkit.

## Before you start

- Open an issue first to discuss the change you want to make
- All submissions must pass PSScriptAnalyzer with zero errors or warnings
- Follow the existing code style — verb-noun cmdlet names, comment-based help on every public function

## Running the checks locally

```powershell
Invoke-ScriptAnalyzer -Path .\Public -Recurse -Severity Error, Warning
Invoke-ScriptAnalyzer -Path .\Private -Recurse -Severity Error, Warning
```

## Pull requests

- One feature or fix per PR
- Update CHANGELOG.md with your change
- PRs without passing CI will not be reviewed

---

---

## Licence

[MIT](LICENSE) — Copyright (c) Malik Oseni

This module uses VMware Horizon PowerCLI as a dependency. VMware PowerCLI is
subject to its own licence terms. This module does not include, distribute, or
modify any VMware binaries.

VMware and VMware Horizon are trademarks of VMware, Inc. This project is not
affiliated with, endorsed by, or certified by VMware.
