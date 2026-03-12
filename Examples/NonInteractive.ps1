#Requires -Version 7.0
<#
.SYNOPSIS
    Example: Pipeline output inspection and WhatIf usage of Invoke-PIMActivation.

.DESCRIPTION
    Demonstrates how to capture and inspect pipeline output from an interactive
    Invoke-PIMActivation run, and how to use -WhatIf for a dry run without
    submitting any Graph activation requests.

    Prerequisites:
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
        Install-Module PwshSpectreConsole             -Scope CurrentUser

    Run this script from the PIMActivator directory, or adjust the module
    path below to match your local clone location.
#>

# ---------------------------------------------------------------------------
# Import from a local clone
# ---------------------------------------------------------------------------

$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PIMActivator\PIMActivator.psd1'
Import-Module -Name (Resolve-Path $manifestPath).Path -Force

# ---------------------------------------------------------------------------
# Connect to Microsoft Graph (full 7-scope set for roles + groups)
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
# Example A: Activate interactively and inspect results
# ---------------------------------------------------------------------------

$results = Invoke-PIMActivation
$results | Format-Table -AutoSize

# ---------------------------------------------------------------------------
# Example B (failure inspection): check for any activation failures
# ---------------------------------------------------------------------------

$failed = $results | Where-Object { $_.Status -eq 'failed' }

if ($failed.Count -gt 0) {
    Write-Warning "$($failed.Count) activation(s) failed:"
    $failed | ForEach-Object {
        Write-Warning "  [$($_.Type)] $($_.Name) — $($_.ErrorMessage)"
    }
}
else {
    Write-Host 'All activations succeeded or are pending approval.' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Example C: Dry run with -WhatIf
#
#   No Graph requests are submitted. Each item is returned with
#   Status = 'skipped' and ErrorMessage = 'WhatIf'.
# ---------------------------------------------------------------------------

Write-Host "`nDry run preview (-WhatIf):" -ForegroundColor Cyan

$dryRun = Invoke-PIMActivation -WhatIf
$dryRun | Select-Object -Property Name, Type, Status, DurationHours | Format-Table -AutoSize
