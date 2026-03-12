#Requires -Version 7.0

function Get-PIMEligibleRole {
    <#
    .SYNOPSIS
        Retrieves all provisioned Entra ID role eligibility schedules for a user.

    .DESCRIPTION
        Queries the Microsoft Graph roleManagement/directory/roleEligibilitySchedules
        endpoint, filtered to the specified principal and status 'Provisioned'.
        The roleDefinition navigation property is expanded so callers can access
        the role's display name without a second Graph call.

        Returns the raw value array from the Graph response. Callers should pass
        each element to ConvertTo-PIMAssignmentObject for a normalised object.

    .PARAMETER UserId
        The Entra ID object GUID of the user whose eligible roles are to be fetched.

    .OUTPUTS
        [array] Raw Graph roleEligibilitySchedule objects with roleDefinition expanded.
        Returns an empty array when the user has no eligible roles or the response
        is null.

    .EXAMPLE
        $roles = Get-PIMEligibleRole -UserId $me.id
        Write-Verbose "Found $($roles.Count) eligible Entra ID role(s)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )

    $encodedFilter = "`$filter=principalId eq '$UserId' and status eq 'Provisioned'"
    $expand        = "`$expand=roleDefinition"
    $uri           = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilitySchedules?$encodedFilter&$expand"

    Write-Verbose "[PIMActivator] Fetching eligible Entra ID roles for principal '$UserId'"
    Write-Verbose "[PIMActivator] URI: $uri"

    $response = Invoke-PIMGraphRequest -Uri $uri

    if ($null -eq $response -or $null -eq $response.value) {
        Write-Verbose '[PIMActivator] Get-PIMEligibleRole: No response or empty value array returned.'
        return @()
    }

    Write-Verbose "[PIMActivator] Get-PIMEligibleRole: Received $($response.value.Count) schedule(s)."
    return $response.value
}
