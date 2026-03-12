#Requires -Version 7.0

function Get-PIMCurrentUser {
    <#
    .SYNOPSIS
        Retrieves the authenticated user's identity from Microsoft Graph.

    .DESCRIPTION
        Calls the /me endpoint of the Microsoft Graph v1.0 API to resolve the
        currently authenticated user. Returns a PSCustomObject containing the
        user's object ID and display name.

        This function is a thin wrapper over Invoke-PIMGraphRequest and is
        typically called once per session; the result is cached by the module
        in $script:PIMCachedUserId.

    .OUTPUTS
        [PSCustomObject] with properties:
            .id          [string]  Entra ID object GUID of the authenticated user.
            .displayName [string]  Human-readable display name.

    .EXAMPLE
        $me = Get-PIMCurrentUser
        Write-Verbose "Running as: $($me.displayName) ($($me.id))"
    #>
    [CmdletBinding()]
    param()

    Write-Verbose '[PIMActivator] Calling GET https://graph.microsoft.com/v1.0/me'

    $response = Invoke-PIMGraphRequest -Uri 'https://graph.microsoft.com/v1.0/me'

    if ($null -eq $response) {
        throw '[PIMActivator] Get-PIMCurrentUser: Graph returned null. Verify the session is authenticated (Run Connect-MgGraph).'
    }

    if ([string]::IsNullOrWhiteSpace($response.id)) {
        throw '[PIMActivator] Get-PIMCurrentUser: Response did not contain a user id. The session may lack the User.Read scope.'
    }

    return [PSCustomObject]@{
        id          = [string]$response.id
        displayName = [string]$response.displayName
    }
}
