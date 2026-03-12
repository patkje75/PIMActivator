#Requires -Version 7.0

function Invoke-PIMTypeFilter {
    <#
    .SYNOPSIS
        Presents a Spectre Console selection prompt to filter PIM assignment types.

    .DESCRIPTION
        When only one type of assignment is available, the function returns the
        appropriate filter string automatically and writes an informational message
        to the terminal. When both Entra ID roles and PIM Group assignments are
        present, it presents an interactive single-choice menu for the user to select
        which category to work with.

        This function never returns $null. It always returns one of the three
        discriminator strings: 'EntraRoles', 'PIMGroups', or 'Both'.

    .PARAMETER RolesCount
        The number of eligible Entra ID role assignments discovered for the current
        user.

    .PARAMETER GroupsCount
        The number of eligible PIM Group assignments discovered for the current user.

    .OUTPUTS
        [string]
        One of: 'EntraRoles' | 'PIMGroups' | 'Both'

    .EXAMPLE
        $filter = Invoke-PIMTypeFilter -RolesCount 3 -GroupsCount 0
        # Returns 'EntraRoles' immediately (no prompt shown).

    .EXAMPLE
        $filter = Invoke-PIMTypeFilter -RolesCount 2 -GroupsCount 5
        # Displays a Read-SpectreSelection menu and returns the user's choice.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$RolesCount,

        [Parameter(Mandatory)]
        [int]$GroupsCount
    )

    # Auto-select when only one type is present — no prompt needed.
    if ($RolesCount -gt 0 -and $GroupsCount -eq 0) {
        Write-SpectreHost "[deepskyblue1]Only Entra ID Role assignments found ($RolesCount). Selecting automatically.[/]"
        return 'EntraRoles'
    }

    if ($GroupsCount -gt 0 -and $RolesCount -eq 0) {
        Write-SpectreHost "[deepskyblue1]Only PIM Group assignments found ($GroupsCount). Selecting automatically.[/]"
        return 'PIMGroups'
    }

    # Both types are present — present a menu.
    $choiceRoles  = "Entra ID Roles only ($RolesCount)"
    $choiceGroups = "PIM Groups only ($GroupsCount)"
    $choiceBoth   = "Both (All $($RolesCount + $GroupsCount) assignments)"

    $choices = @($choiceRoles, $choiceGroups, $choiceBoth)

    $selected = Read-SpectreSelection `
        -Title 'What would you like to activate?' `
        -Choices $choices `
        -PageSize 5

    switch ($selected) {
        $choiceRoles  { return 'EntraRoles' }
        $choiceGroups { return 'PIMGroups'  }
        default       { return 'Both'       }
    }
}
