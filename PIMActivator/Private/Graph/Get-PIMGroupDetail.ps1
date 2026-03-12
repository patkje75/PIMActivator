#Requires -Version 7.0

function Get-PIMGroupDetail {
    <#
    .SYNOPSIS
        Retrieves the id and displayName of an Entra ID group by its object GUID.

    .DESCRIPTION
        Calls the Microsoft Graph /groups/{GroupId} endpoint with a $select
        projection limited to id and displayName. This function is used to enrich
        PIM group eligibility schedules where the group navigation property was not
        expanded (or was absent) in the upstream call.

        On error (e.g. 404 Not Found, permission denied), the function returns
        $null rather than throwing, allowing callers to apply a graceful fallback
        display name.

    .PARAMETER GroupId
        The Entra ID object GUID of the group to retrieve.

    .OUTPUTS
        [PSCustomObject] with properties:
            .id          [string]  Group object GUID.
            .displayName [string]  Group display name.

        Returns $null if the Graph call fails or returns no usable data.

    .EXAMPLE
        $details = Get-PIMGroupDetail -GroupId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
        $groupName = $details?.displayName ?? "Group ($GroupId)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId?`$select=id,displayName"

    Write-Verbose "[PIMActivator] Fetching group details for '$GroupId'"

    $response = Invoke-PIMGraphRequest -Uri $uri

    if ($null -eq $response -or [string]::IsNullOrWhiteSpace($response.id)) {
        Write-Verbose "[PIMActivator] Get-PIMGroupDetail: No valid response for group '$GroupId'."
        return $null
    }

    return [PSCustomObject]@{
        id          = [string]$response.id
        displayName = [string]$response.displayName
    }
}
