#Requires -Version 7.0
<#
.SYNOPSIS
    Example: Basic interactive PIM activation using PIMActivator.

.DESCRIPTION
    Demonstrates the simplest end-to-end usage of Invoke-PIMActivation in fully
    interactive mode. Every prompt — assignment type filter, assignment selection,
    justification, and per-assignment duration — is presented through Spectre
    Console UI.

    Prerequisites:
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
        Install-Module PwshSpectreConsole             -Scope CurrentUser

    Run this script from the PIMActivator directory, or adjust the module
    path in step 2 to match your local clone location.
#>

# ---------------------------------------------------------------------------
# Step 1: Prerequisites check
# ---------------------------------------------------------------------------

# Verify PowerShell 7+ is in use (enforced by #Requires above).
# Verify required modules are available.

$requiredModules = @(
    @{ Name = 'Microsoft.Graph.Authentication'; MinVersion = '2.0.0' }
    @{ Name = 'PwshSpectreConsole';             MinVersion = '1.0.0' }
)

foreach ($req in $requiredModules) {
    $mod = Get-Module -Name $req.Name -ListAvailable |
           Where-Object { $_.Version -ge [version]$req.MinVersion } |
           Select-Object -First 1

    if (-not $mod) {
        Write-Warning "Required module '$($req.Name)' >= $($req.MinVersion) is not installed."
        Write-Warning "Install it with: Install-Module $($req.Name) -Scope CurrentUser"
    }
}

# ---------------------------------------------------------------------------
# Step 2: Import the PIMActivator module from a local clone
# ---------------------------------------------------------------------------

$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PIMActivator\PIMActivator.psd1'
Import-Module -Name (Resolve-Path $manifestPath).Path -Force

# ---------------------------------------------------------------------------
# Step 3: Connect to Microsoft Graph
#
#   Use the full 7-scope set to enable both Entra ID role activation and
#   PIM group membership activation. If you only need Entra ID roles, use
#   the 4-scope set shown in the README.
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
# Step 4: Run the interactive activation workflow
#
#   Invoke-PIMActivation with no parameters presents:
#     - A type filter prompt (EntraRoles / PIMGroups / Both)
#     - A multi-select list of eligible assignments
#     - A justification text prompt
#     - A per-assignment duration prompt for each selected item
#
#   An activation summary table is shown on completion.
# ---------------------------------------------------------------------------

Invoke-PIMActivation

# ---------------------------------------------------------------------------
# Step 5 (optional): Capture and inspect the pipeline output
# ---------------------------------------------------------------------------

# Uncomment the lines below to capture results and inspect them.
#
# $results = Invoke-PIMActivation
#
# $results | Format-Table -AutoSize
#
# $failed = $results | Where-Object { $_.Status -eq 'failed' }
# if ($failed.Count -gt 0) {
#     Write-Warning "$($failed.Count) activation(s) failed:"
#     $failed | ForEach-Object {
#         Write-Warning "  $($_.Name): $($_.ErrorMessage)"
#     }
# }
