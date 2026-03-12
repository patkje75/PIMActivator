#Requires -Version 7.0

function Invoke-PIMGraphConnect {
    <#
    .SYNOPSIS
        Interactively prompts the user to connect to Microsoft Graph with PIM scopes.

    .DESCRIPTION
        Displays a Spectre Console selection menu offering two scope presets:

            Roles + Groups  (7 scopes, recommended) — activates both Entra ID roles
                            and PIM group memberships.
            Roles only      (4 scopes) — activates Entra ID roles only.

        Calls Connect-MgGraph with the chosen scopes. Returns $true when a session
        is established, $false when the user selects Exit or the connection fails.

        This function never throws; all errors are surfaced as Spectre markup lines.

    .OUTPUTS
        [bool] $true if the Graph session is now active; $false otherwise.

    .EXAMPLE
        if (-not (Invoke-PIMGraphConnect)) { return @() }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $rolesScopes = @(
        'RoleEligibilitySchedule.Read.Directory'
        'RoleAssignmentSchedule.Read.Directory'
        'RoleAssignmentSchedule.ReadWrite.Directory'
        'RoleManagementPolicy.Read.Directory'
    )

    $groupScopes = @(
        'PrivilegedEligibilitySchedule.Read.AzureADGroup'
        'PrivilegedAssignmentSchedule.Read.AzureADGroup'
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
    )

    Write-SpectreHost ''
    Write-SpectreHost '[yellow]Not connected to Microsoft Graph.[/]'
    Write-SpectreHost '[grey]Select a permission scope to authenticate with, or exit.[/]'
    Write-SpectreHost ''

    $choices = @(
        'Roles + Groups  (7 scopes)'
        'Roles only      (4 scopes)'
        'Exit'
    )

    $selection = Read-SpectreSelection `
        -Message 'Connect to Microsoft Graph' `
        -Choices $choices

    if ($selection -match '^Exit') {
        return $false
    }

    $scopes = if ($selection -match '^Roles \+ Groups') {
        $rolesScopes + $groupScopes
    }
    else {
        $rolesScopes
    }

    Write-SpectreHost '[grey]Opening browser for authentication...[/]'

    try {
        Connect-MgGraph -Scopes $scopes -ErrorAction Stop | Out-Null

        $ctx = Get-MgContext
        if ($null -eq $ctx) {
            Write-SpectreHost '[red]Connection could not be verified. Please try again.[/]'
            return $false
        }

        Write-SpectreHost "[green]Connected as:[/] [deepskyblue1]$($ctx.Account)[/]"
        return $true
    }
    catch {
        Write-SpectreHost "[red]Connection error: $(Get-SpectreEscapedText -Text $_.Exception.Message)[/]"
        return $false
    }
}
