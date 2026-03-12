#Requires -Version 7.0

function Get-PIMEligibleGroup {
    <#
    .SYNOPSIS
        Retrieves all provisioned PIM group eligibility schedules for a user.

    .DESCRIPTION
        Queries the Microsoft Graph identityGovernance/privilegedAccess/group/
        eligibilitySchedules endpoint, filtered to the specified principal and
        status 'Provisioned'. The group navigation property is expanded so callers
        can access the group's display name without a second Graph call.

        Returns the raw value array from the Graph response. Callers should pass
        each element to ConvertTo-PIMAssignmentObject for a normalised object.

    .PARAMETER UserId
        The Entra ID object GUID of the user whose PIM group eligibilities are
        to be fetched.

    .OUTPUTS
        [array] Raw Graph privilegedAccessGroupEligibilitySchedule objects with
        group expanded. Returns an empty array when the user has no eligible group
        memberships or the response is null.

    .EXAMPLE
        $groups = Get-PIMEligibleGroup -UserId $me.id
        Write-Verbose "Found $($groups.Count) eligible PIM group assignment(s)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )

    $encodedFilter = "`$filter=principalId eq '$UserId' and status eq 'Provisioned'"
    $expand        = "`$expand=group"
    $uri           = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/eligibilitySchedules?$encodedFilter&$expand"

    Write-Verbose "[PIMActivator] Fetching eligible PIM group assignments for principal '$UserId'"
    Write-Verbose "[PIMActivator] URI: $uri"

    $response = Invoke-PIMGraphRequest -Uri $uri

    if ($null -eq $response -or $null -eq $response.value) {
        Write-Verbose '[PIMActivator] Get-PIMEligibleGroup: No response or empty value array returned.'
        return @()
    }

    Write-Verbose "[PIMActivator] Get-PIMEligibleGroup: Received $($response.value.Count) schedule(s)."
    return $response.value
}
