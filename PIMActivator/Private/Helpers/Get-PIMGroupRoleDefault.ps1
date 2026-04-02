#Requires -Version 7.0

function Get-PIMGroupRoleDefault {
    <#
    .SYNOPSIS
        Returns the hardcoded default maximum activation duration (in hours) for a
        PIM group based on Azure Landing Zone naming conventions.

    .DESCRIPTION
        Applies a priority-ordered set of pattern rules to the group display name
        and returns a duration in whole hours. This is used as a fallback when the
        Graph policy API is unreachable or returns no policy for the group.

        Rules (evaluated top-to-bottom, first match wins):

            Rule 1  root + owner  ('*-root*' AND '*-owner*')  -->  1 hour
                    Most sensitive combination; minimal access window.

            Rule 2  root only     ('*-root*')                 -->  2 hours
                    Root management group without ownership rights.

            Rule 3  owner only    ('*-owner*')                -->  4 hours
                    Non-root owner role.

            Rule 4  platform contributor/reader               -->  4 hours
                    Matches $script:PIMPlatformPatterns via Test-PIMPlatformScope.

            Rule 5  production subscription ('*-p-*')         -->  4 hours
                    Production subscriptions with stricter policy limits.

            Rule 6  default (landing zone contributor/reader) -->  8 hours

        Naming convention examples:
            'azr-pag-mg-root-owner'                       -> 1h  (root + owner)
            'azr-pag-mg-root-contributor'                 -> 2h  (root only)
            'azr-pag-mg-connectivity-owner'               -> 4h  (owner; platform scope)
            'azr-pag-sub-integrations-01-p-contributor'   -> 4h  (production)
            'azr-pag-sub-analytics-contributor'           -> 8h  (landing zone default)

    .PARAMETER GroupName
        The display name of the PIM group.

    .OUTPUTS
        [int] Default maximum activation duration in whole hours.

    .EXAMPLE
        Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-owner'
        # Returns: 1

    .EXAMPLE
        Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-analytics-contributor'
        # Returns: 8
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    # Rule 1: root + owner  (must check combined pattern first)
    if ($GroupName -like '*-root*' -and $GroupName -like '*-owner*') {
        Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched root+owner rule -> 1h"
        return 1
    }

    # Rule 2: root only
    if ($GroupName -like '*-root*') {
        Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched root rule -> 2h"
        return 2
    }

    # Rule 3: owner only (any scope)
    if ($GroupName -like '*-owner*') {
        Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched owner rule -> 4h"
        return 4
    }

    # Rule 4: contributor/reader in platform scope
    if (Test-PIMPlatformScope -GroupName $GroupName) {
        Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched platform-scope rule -> 4h"
        return 4
    }

    # Rule 5: production subscription (name contains '-p-' segment)
    if ($GroupName -like '*-p-*') {
        Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched production rule -> 4h"
        return 4
    }

    # Rule 6: landing zone default
    Write-Verbose "[PIMActivator] Get-PIMGroupRoleDefault: '$GroupName' matched default rule -> 8h"
    return 8
}
