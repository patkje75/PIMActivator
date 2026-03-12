#Requires -Version 7.0

function Test-PIMPlatformScope {
    <#
    .SYNOPSIS
        Tests whether a PIM group name matches a platform-scope naming pattern.

    .DESCRIPTION
        Iterates over the module-scoped variable $script:PIMPlatformPatterns (an
        array of wildcard strings) and returns $true if the supplied group name
        matches any of them via the -like operator.

        The patterns are defined at the module level and default to an empty array
        when the module is first loaded. The public Invoke-PIMActivation function
        (or a test harness) is responsible for populating $script:PIMPlatformPatterns
        before calling this helper.

        Platform-scope groups receive stricter default duration limits in
        Get-PIMGroupRoleDefault. Typical patterns:
            '*-connectivity-*'
            '*-platform-*'
            '*-management-*'
            '*-identity-*'
            '*-security-*'

    .PARAMETER GroupName
        The display name of the PIM group to test.

    .OUTPUTS
        [bool] $true if the group name matches at least one platform pattern;
               $false otherwise (including when $script:PIMPlatformPatterns is empty).

    .EXAMPLE
        $script:PIMPlatformPatterns = @('*-connectivity-*', '*-management-*')
        Test-PIMPlatformScope -GroupName 'azr-pag-mg-connectivity-contributor'
        # Returns: $true

    .EXAMPLE
        Test-PIMPlatformScope -GroupName 'azr-pag-sub-analytics-contributor'
        # Returns: $false (assuming no matching pattern is configured)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    if ($null -eq $script:PIMPlatformPatterns -or $script:PIMPlatformPatterns.Count -eq 0) {
        return $false
    }

    foreach ($pattern in $script:PIMPlatformPatterns) {
        if ($GroupName -like $pattern) {
            Write-Verbose "[PIMActivator] Test-PIMPlatformScope: '$GroupName' matched platform pattern '$pattern'."
            return $true
        }
    }

    return $false
}
