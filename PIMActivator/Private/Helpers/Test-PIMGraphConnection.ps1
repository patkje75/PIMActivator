#Requires -Version 7.0

function Test-PIMGraphConnection {
    <#
    .SYNOPSIS
        Tests whether an active Microsoft Graph session exists.

    .DESCRIPTION
        Calls Get-MgContext and returns $true when the result is non-null (i.e.
        Connect-MgGraph has been called and the token has not expired). Returns
        $false in all other cases, including when Get-MgContext itself throws.

        This function is intentionally non-throwing; it is designed to be used as
        a guard check before performing Graph operations.

    .OUTPUTS
        [bool] $true if a Graph context is active; $false otherwise.

    .EXAMPLE
        if (-not (Test-PIMGraphConnection)) {
            throw 'Not connected to Microsoft Graph. Run Connect-MgGraph first.'
        }
    #>
    [CmdletBinding()]
    param()

    try {
        $ctx = Get-MgContext
        if ($null -eq $ctx) {
            Write-Verbose '[PIMActivator] Test-PIMGraphConnection: Get-MgContext returned null.'
            return $false
        }
        Write-Verbose "[PIMActivator] Test-PIMGraphConnection: Connected as '$($ctx.Account)' to tenant '$($ctx.TenantId)'."
        return $true
    }
    catch {
        Write-Verbose "[PIMActivator] Test-PIMGraphConnection: Get-MgContext threw - $_"
        return $false
    }
}
