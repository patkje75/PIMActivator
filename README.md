# PIMActivator

[![CI](https://github.com/patkje75/PIMActivator/actions/workflows/ci.yml/badge.svg)](https://github.com/patkje75/PIMActivator/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 7.0+](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![PwshSpectreConsole Required](https://img.shields.io/badge/PwshSpectreConsole-Required-orange)](https://github.com/ShaunLawrie/PwshSpectreConsole)

Activating PIM roles in the Entra portal is tedious — navigate, find your
assignment, fill in duration and justification, submit — for every role, every
time. PIMActivator turns that into a single terminal command with an interactive
multi-select UI. It handles both **Entra ID directory roles** and **PIM group
memberships** in one pass and enforces duration policies automatically. All
prompts are interactive; non-interactive parameter support is planned for a
future release.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Required Permissions](#required-permissions)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Parameter Reference](#parameter-reference)
- [How It Works](#how-it-works)
- [Graph API Reference](#graph-api-reference)
- [Activation Status Reference](#activation-status-reference)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)



## Features

- **Interactive multi-select UI** — Spectre Console-rendered checklist; pick any subset of your eligible assignments in one pass.
- **Entra ID roles + PIM group memberships** — both assignment types handled in the same invocation.
- **Policy-aware durations** — queries the Graph role management policy for each assignment and caps or defaults to the allowed maximum automatically.
- **Flexible justification** — prompted once when a single assignment is selected; or choose between one shared justification or a separate one per assignment when 2+ are selected.
- **`-WhatIf` support** — dry-run mode shows exactly what would be activated without submitting any Graph requests.
- **Structured pipeline output** — every activation returns a `[PSCustomObject]` with `Name`, `Type`, `Status`, `DurationHours`, and `ErrorMessage` for downstream processing.
- **PowerShell 7+ only** — no PS 5.1 compatibility shims; freely uses null-coalescing, ternary expressions, and other modern syntax.

## Planned Features
- **Non-interactive mode** — parameter-driven automation (`-Justification`, `-DurationHours`, and type filtering) is planned for a future release.

## Demo

![PIMActivator demo](Media/Demo.gif)


---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| PowerShell | 7.0+ | Core edition only — `CompatiblePSEditions = Core` |
| Microsoft.Graph.Authentication | 2.0.0+ | Graph SDK authentication module |
| PwshSpectreConsole | 1.0.0+ | **Required** — install before importing the module |

---

## Required Permissions

You must be connected to Microsoft Graph with the appropriate delegated scopes before calling `Invoke-PIMActivation`. The module throws if a Graph connection is not present and will warn when group-related scopes are missing.

### Entra ID Roles only

Use this scope set if you only need to activate Entra ID directory roles:

```powershell
Connect-MgGraph -Scopes @(
    'RoleEligibilitySchedule.Read.Directory',
    'RoleAssignmentSchedule.Read.Directory',
    'RoleAssignmentSchedule.ReadWrite.Directory',
    'RoleManagementPolicy.Read.Directory'
)
```

### Entra ID Roles + PIM Groups

Use this scope set to activate both Entra ID roles and PIM group memberships:

```powershell
Connect-MgGraph -Scopes @(
    'RoleEligibilitySchedule.Read.Directory',
    'RoleAssignmentSchedule.Read.Directory',
    'RoleAssignmentSchedule.ReadWrite.Directory',
    'RoleManagementPolicy.Read.Directory',
    'PrivilegedEligibilitySchedule.Read.AzureADGroup',
    'PrivilegedAssignmentSchedule.Read.AzureADGroup',
    'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
)
```

### Scope Reference

| Scope | Purpose |
|---|---|
| `RoleEligibilitySchedule.Read.Directory` | Read eligible Entra ID role assignments |
| `RoleAssignmentSchedule.Read.Directory` | Read active Entra ID role assignment schedules |
| `RoleAssignmentSchedule.ReadWrite.Directory` | Create Entra ID role activation requests |
| `RoleManagementPolicy.Read.Directory` | Read role management policies (max duration) |
| `PrivilegedEligibilitySchedule.Read.AzureADGroup` | Read eligible PIM group memberships |
| `PrivilegedAssignmentSchedule.Read.AzureADGroup` | Read active PIM group assignment schedules |
| `PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup` | Create PIM group activation requests |

---

## Installation

```powershell
# 1. Install required modules
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module PwshSpectreConsole -Scope CurrentUser

# 2. Import from local clone
Import-Module .\PIMActivator\PIMActivator.psd1 -Force

# 3. Or use the install script (copies module to your PSModulePath)
.\Install-PIMActivator.ps1
```

> PwshSpectreConsole must be installed **before** importing PIMActivator. The module will not attempt to install it automatically — import will fail with a missing required module error if it is absent.

---

## Quick Start

```powershell
# 1. Interactive activation — no pre-authentication needed
#    If you are not connected to Microsoft Graph, PIMActivator will prompt you
#    to choose a scope preset (Roles + Groups, or Roles only) and open a browser
#    for OAuth sign-in automatically.
Invoke-PIMActivation

# 2. WhatIf — preview what would be activated without making any API calls
Invoke-PIMActivation -WhatIf
```

## Parameter Reference

All parameters belong to `Invoke-PIMActivation`.

| Parameter | Type | Description |
|---|---|---|
| `WhatIf` | `switch` | Standard PowerShell `-WhatIf` support via `SupportsShouldProcess`. Shows what would be activated without making any Graph API calls. |

> Non-interactive parameters are planned for a future release.

---

## How It Works

`Invoke-PIMActivation` orchestrates the following eight-step flow:

1. **Display banner** — `Write-SpectreRule` renders a titled horizontal rule to mark the start of the session.

2. **Test-PIMGraphConnection** — checks for an active Microsoft Graph connection. If no connection is found, the function throws a terminating error and displays guidance for running `Connect-MgGraph` with the required scopes.

3. **Assert-PIMRequiredScopes** — inspects the scopes granted on the current Graph context. Missing group-related scopes produce a warning (roles-only workflow continues). Missing role-related scopes produce a terminating error.

4. **Get-PIMCurrentUser** — calls `/v1.0/me` and displays a `Connected as: {displayName}` status line via PwshSpectreConsole.

5. **Get-PIMEligibleRoles + Get-PIMEligibleGroups** — queries the Graph eligibility schedule endpoints and converts results into normalized assignment objects shared across the rest of the pipeline.

6. **Invoke-PIMTypeFilter** — presents a type-selection prompt (`EntraRoles`, `PIMGroups`, `Both`).

7. **Invoke-PIMMultiSelect** — renders a `Read-SpectreMultiSelection` list for the user to pick assignments.

   **Justification resolution** follows immediately after selection:
   - Exactly 1 assignment selected → a single justification prompt is shown.
   - 2+ assignments selected interactively → a `Read-SpectreSelection` menu offers:
     - **Same for all assignments** — one shared prompt, reused for every activation (previous behaviour).
     - **Different per assignment** — a separate prompt is shown for each assignment during the queue-build phase.

   Justification is always submitted with every activation request, even when the tenant's PIM policy does not require it.

   `Invoke-PIMDurationPrompt` is then called per assignment to set durations, with policy enforcement via the Graph policy assignment endpoint.

8. **Show-PIMActivationProgress** — processes the activation queue **sequentially**, one item at a time. Each activation request is dispatched, its result is checked, and per-item UI feedback is shown before the next item begins. A per-item retry is performed on transient failures. Results are collected and rendered as a colour-coded summary table via `Show-PIMActivationSummary`.

---

## Graph API Reference

| Operation | Endpoint | Method |
|---|---|---|
| Current user | `/v1.0/me` | GET |
| Eligible Entra roles | `/v1.0/roleManagement/directory/roleEligibilitySchedules` | GET |
| Eligible PIM groups | `/v1.0/identityGovernance/privilegedAccess/group/eligibilitySchedules` | GET |
| Role max duration | `/v1.0/policies/roleManagementPolicyAssignments` | GET |
| Group max duration | `/v1.0/policies/roleManagementPolicyAssignments` (scope=Group) | GET |
| Activate Entra role | `/v1.0/roleManagement/directory/roleAssignmentScheduleRequests` | POST |
| Activate PIM group | `/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests` | POST |

All calls use delegated authentication via `Invoke-MgGraphRequest` from `Microsoft.Graph.Authentication`. No application permissions are used.

---

## Activation Status Reference

The structured `[PSCustomObject]` output returned by `Invoke-PIMActivation` (and displayed in the summary table) includes a `Status` field with one of the following values:

| Status | Meaning |
|---|---|
| `granted` | Activation successful — the role or group membership is now active. |
| `provisioned` | Activation accepted and successfully provisioned in the directory. |
| `pendingApproval` | Activation request submitted but requires approval from a designated PIM approver. |
| `pendingProvisioning` | Activation accepted and queued; provisioning has not completed yet. |
| `failed` | Activation failed. Inspect the `ErrorMessage` property for details. |
| `skipped` | Assignment was skipped due to `-WhatIf` or the user entering `0` at a duration prompt. |

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| `Import-Module` fails with "required module not found" | PwshSpectreConsole is not installed | Run `Install-Module PwshSpectreConsole -Scope CurrentUser` before importing the module |
| `Invoke-PIMActivation` throws "No active Microsoft Graph connection" | `Connect-MgGraph` has not been called | Run `Connect-MgGraph` with the scopes listed in [Required Permissions](#required-permissions) |
| "Insufficient privileges" error during activation | Missing `ReadWrite` scope | Disconnect and reconnect with the full scope set; check that your account has PIM eligible assignments |
| No assignments appear in the multi-select list | No PIM eligible assignments exist, or wrong scope set | Verify eligibility in the Entra portal; ensure you connected with the correct scope set for roles vs. groups |
| `pendingApproval` status on all activations | Your tenant's PIM policy requires approver sign-off | Contact your PIM approver; approval is a tenant policy decision outside this module's control |
| Duration prompt rejects your input | Value exceeds the policy maximum for that assignment | Enter a value at or below the displayed policy maximum |
| Spectre UI renders garbled characters in Windows Terminal | Console encoding mismatch | Ensure your terminal is using UTF-8: run `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` |
| Activations fail partway through the queue with authentication errors | Graph token expired mid-run — the module does not re-authenticate automatically; remaining queue items surface as `failed` | Reconnect with `Connect-MgGraph` using the required scopes and re-run `Invoke-PIMActivation` |
| `RoleManagementPolicy.Read.Directory` scope warning on first connect | Scope not included in `Connect-MgGraph` call | Add the scope to your connect call; without it, max-duration policy checks are skipped and defaults are used |

### Common Graph API Errors

When an activation item shows `failed` status, inspect its `ErrorMessage` property. The following Graph error codes have specific meanings in the PIM context:

| HTTP Status | Meaning in PIM context |
|---|---|
| `403 Forbidden` | A required delegated scope is missing from the current Graph context. Disconnect and reconnect with the full scope set listed in [Required Permissions](#required-permissions). |
| `429 Too Many Requests` | Graph API is throttling the request. The module performs a per-item retry; if the error persists, wait a few minutes and re-run. |
| `400 Bad Request` | Policy violation — common causes include the role or group membership already being active, a justification string that is too short, or a requested duration that exceeds the policy maximum. |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
