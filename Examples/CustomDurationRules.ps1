#Requires -Version 7.0
<#
.SYNOPSIS
    Example: Understanding the automatic duration layers in PIMActivator.

.DESCRIPTION
    PIMActivator uses a layered approach to determine the default activation
    duration for each assignment:

        Layer 1 — Graph policy (Get-PIMGroupMaxDuration)
                  Queries the roleManagementPolicyAssignments endpoint for the
                  group. Returns the maximum duration defined in the Entra ID
                  policy. Used when group scopes are present and the API responds.

        Layer 2 — Hardcoded name-based defaults (Get-PIMGroupRoleDefault)
                  Applied when the policy cannot be retrieved (e.g. 403) or
                  returns no data. Rules are evaluated top-to-bottom:

                      Rule 1 — root + owner  (name matches *-root* AND *-owner*)  1 h
                      Rule 2 — root only     (name matches *-root*)               2 h
                      Rule 3 — owner only    (name matches *-owner*)              4 h
                      Rule 4 — platform scope contributor/reader                  4 h
                      Rule 5 — default (landing-zone contributor/reader)          8 h

    The resolved default is presented as the pre-filled value in the interactive
    duration prompt. The user can accept it or enter a different value (up to the
    policy maximum).

    Prerequisites:
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
        Install-Module PwshSpectreConsole             -Scope CurrentUser
#>

# ---------------------------------------------------------------------------
# Import from a local clone
# ---------------------------------------------------------------------------

$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PIMActivator\PIMActivator.psd1'
Import-Module -Name (Resolve-Path $manifestPath).Path -Force

# ---------------------------------------------------------------------------
# Hardcoded rule reference table (for documentation purposes)
# ---------------------------------------------------------------------------

$ruleTable = @(
    [PSCustomObject]@{ GroupNamePattern = '*-root*-owner*'; DefaultHours = 1; Reason = 'Root + owner — most sensitive' }
    [PSCustomObject]@{ GroupNamePattern = '*-root*';        DefaultHours = 2; Reason = 'Root scope without owner' }
    [PSCustomObject]@{ GroupNamePattern = '*-owner*';       DefaultHours = 4; Reason = 'Non-root owner role' }
    [PSCustomObject]@{ GroupNamePattern = 'Platform scope'; DefaultHours = 4; Reason = 'Platform contributor/reader' }
    [PSCustomObject]@{ GroupNamePattern = '(default)';      DefaultHours = 8; Reason = 'Landing-zone contributor/reader' }
)

Write-Host "`nGet-PIMGroupRoleDefault rule reference:" -ForegroundColor Cyan
$ruleTable | Format-Table -AutoSize

# ---------------------------------------------------------------------------
# Naming convention examples and their resolved default hours
# ---------------------------------------------------------------------------

$namingExamples = @(
    'azr-pag-mg-root-owner'
    'azr-pag-mg-root-contributor'
    'azr-pag-mg-connectivity-owner'
    'azr-pag-mg-connectivity-contributor'
    'azr-pag-sub-analytics-contributor'
    'azr-pag-sub-identity-reader'
)

Write-Host "`nName-based default resolution examples:" -ForegroundColor Cyan

$namingExamples | ForEach-Object {
    $hours = Get-PIMGroupRoleDefault -GroupName $_
    [PSCustomObject]@{
        GroupName    = $_
        DefaultHours = $hours
    }
} | Format-Table -AutoSize

# ---------------------------------------------------------------------------
# Connect to Graph (required for the live examples below)
# ---------------------------------------------------------------------------

Connect-MgGraph -Scopes @(
    'RoleEligibilitySchedule.Read.Directory',
    'RoleAssignmentSchedule.Read.Directory',
    'RoleAssignmentSchedule.ReadWrite.Directory',
    'PrivilegedEligibilitySchedule.Read.AzureADGroup',
    'PrivilegedAssignmentSchedule.Read.AzureADGroup',
    'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup',
    'RoleManagementPolicy.Read.Directory'
)

# ---------------------------------------------------------------------------
# Example A: Interactive activation — per-item duration prompts are shown
#
#   Invoke-PIMDurationPrompt is displayed for each selected assignment.
#   The default value shown in the prompt is Min(Get-PIMGroupRoleDefault, PolicyMax).
#   Entering 0 skips the item.
# ---------------------------------------------------------------------------

Write-Host "`nExample A: Interactive (per-item duration prompts shown)" -ForegroundColor Cyan
Invoke-PIMActivation

# ---------------------------------------------------------------------------
# Example B: Preview resolved durations without activating
#
#   Use -WhatIf to see which assignments would be activated and for how long,
#   based on the policy layer and name-based defaults, without submitting any
#   Graph requests.
# ---------------------------------------------------------------------------

Write-Host "`nExample B: Preview resolved durations with -WhatIf" -ForegroundColor Cyan
$preview = Invoke-PIMActivation -WhatIf
$preview | Select-Object -Property Name, Type, DurationHours | Format-Table -AutoSize
