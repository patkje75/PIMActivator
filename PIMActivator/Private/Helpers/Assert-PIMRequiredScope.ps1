#Requires -Version 7.0

function Assert-PIMRequiredScope {
    <#
    .SYNOPSIS
        Validates that the current Microsoft Graph session has the permissions
        required by PIMActivator.

    .DESCRIPTION
        Reads the scopes from the active MgContext and checks two sets:

        Required (Entra ID role activation) - throws if any are missing:
            RoleEligibilitySchedule.Read.Directory
            RoleAssignmentSchedule.Read.Directory
            RoleAssignmentSchedule.ReadWrite.Directory

        Optional (PIM group activation) - emits Write-Warning if any are missing:
            PrivilegedEligibilitySchedule.Read.AzureADGroup
            PrivilegedAssignmentSchedule.Read.AzureADGroup
            PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup

        Returns $true when both required AND optional scopes are present (full
        capability), $false when only the required role scopes are present.

        Throws a descriptive message with reconnect guidance when required scopes
        are missing.

    .OUTPUTS
        [bool] $true  - Full capability: Entra ID roles + PIM groups enabled.
               $false - Partial capability: Entra ID roles only; PIM groups unavailable.

    .EXAMPLE
        $groupsEnabled = Assert-PIMRequiredScope
        if (-not $groupsEnabled) {
            Write-Verbose 'PIM group activation is unavailable - skipping group enumeration.'
        }

    .EXAMPLE
        # Full reconnect guidance is embedded in the thrown message
        try { Assert-PIMRequiredScope }
        catch { Write-Error $_ }
    #>
    [CmdletBinding()]
    param()

    $requiredScopes = @(
        'RoleEligibilitySchedule.Read.Directory'
        'RoleAssignmentSchedule.Read.Directory'
        'RoleAssignmentSchedule.ReadWrite.Directory'
    )

    $optionalScopes = @(
        'PrivilegedEligibilitySchedule.Read.AzureADGroup'
        'PrivilegedAssignmentSchedule.Read.AzureADGroup'
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
    )

    $ctx = Get-MgContext
    if ($null -eq $ctx) {
        $allScopes = ($requiredScopes + $optionalScopes) -join "','"
        throw (
            "[PIMActivator] Not connected to Microsoft Graph. Run Connect-MgGraph first.`n" +
            "Recommended command:`n" +
            "  Connect-MgGraph -Scopes '$allScopes'"
        )
    }

    $grantedScopes = @($ctx.Scopes)

    # Check required scopes
    $missingRequired = $requiredScopes | Where-Object { $_ -notin $grantedScopes }
    if ($missingRequired.Count -gt 0) {
        $missingList   = $missingRequired -join "','"
        $allScopes     = ($requiredScopes + $optionalScopes) -join "','"
        throw (
            "[PIMActivator] Missing required Graph permission(s): '$missingList'.`n" +
            "Reconnect with all required scopes:`n" +
            "  Connect-MgGraph -Scopes '$allScopes'"
        )
    }

    Write-Verbose '[PIMActivator] Assert-PIMRequiredScope: All required role scopes are present.'

    # Check optional group scopes
    $missingOptional = $optionalScopes | Where-Object { $_ -notin $grantedScopes }
    if ($missingOptional.Count -gt 0) {
        $missingList = $missingOptional -join "','"
        $allScopes   = ($requiredScopes + $optionalScopes) -join "','"
        Write-Warning (
            "[PIMActivator] Missing optional Graph permission(s): '$missingList'. " +
            "PIM group activation will be unavailable.`n" +
            "To enable group activation, reconnect with:`n" +
            "  Connect-MgGraph -Scopes '$allScopes'"
        )
        return $false
    }

    Write-Verbose '[PIMActivator] Assert-PIMRequiredScope: All required and optional scopes are present. Full capability enabled.'
    return $true
}
