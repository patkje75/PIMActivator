#Requires -Version 7.0

function Submit-PIMGroupActivation {
    <#
    .SYNOPSIS
        Submits a self-activation request for a PIM group membership or ownership.

    .DESCRIPTION
        Posts an assignmentScheduleRequest with action 'selfActivate' to the
        Microsoft Graph identityGovernance/privilegedAccess/group/assignmentScheduleRequests
        endpoint. The duration is expressed as an ISO 8601 duration string
        converted from the supplied DurationHours parameter.

        Returns a normalised result hashtable regardless of success or failure,
        allowing the caller to process activations in a loop without try/catch
        boilerplate at the call site.

    .PARAMETER UserId
        Entra ID object GUID of the user activating the group assignment (principalId).

    .PARAMETER GroupId
        Entra ID object GUID of the PIM-managed group.

    .PARAMETER AccessId
        The access level being activated: 'member' or 'owner'.

    .PARAMETER Justification
        Business justification string included in the activation request.

    .PARAMETER DurationHours
        Desired activation duration in whole hours. Converted to ISO 8601
        internally via ConvertTo-PIMIso8601Duration.

    .OUTPUTS
        [hashtable] with keys:
            Status       [string]  One of: 'granted', 'provisioned',
                                   'pendingApproval', 'pendingProvisioning', 'failed'.
            ErrorMessage [string|null]  Populated when Status is 'failed'.
            ExpiresAt    [string|null]  endDateTime from scheduleInfo when present.

    .EXAMPLE
        $result = Submit-PIMGroupActivation `
            -UserId        $me.id `
            -GroupId       $assignment.GroupId `
            -AccessId      $assignment.AccessId `
            -Justification 'Access required for deployment' `
            -DurationHours 4

        if ($result.Status -eq 'failed') {
            Write-Warning "Group activation failed: $($result.ErrorMessage)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$GroupId,

        [Parameter(Mandatory)]
        [string]$AccessId,

        [Parameter(Mandatory)]
        [string]$Justification,

        [Parameter(Mandatory)]
        [int]$DurationHours
    )

    $durationMinutes = $DurationHours * 60
    $isoDuration     = ConvertTo-PIMIso8601Duration -Minutes $durationMinutes

    $body = @{
        action       = 'selfActivate'
        principalId  = $UserId
        groupId      = $GroupId
        accessId     = $AccessId
        justification = $Justification
        scheduleInfo = @{
            expiration = @{
                type     = 'afterDuration'
                duration = $isoDuration
            }
        }
    }

    $uri = 'https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests'

    Write-Verbose "[PIMActivator] Submitting PIM group activation: groupId='$GroupId', accessId='$AccessId', duration='$isoDuration'"

    $response = Invoke-PIMGraphRequest -Uri $uri -Method POST -Body $body -ReturnErrorDetails

    # Structured error returned by Invoke-PIMGraphRequest
    if ($response -is [hashtable] -and $response.ContainsKey('Success') -and $response.Success -eq $false) {
        $errMsg = $response.ErrorMessage
        if ($response.ErrorDetails -and $response.ErrorDetails.message) {
            $errMsg = $response.ErrorDetails.message
        }
        Write-Verbose "[PIMActivator] Submit-PIMGroupActivation: API error - $errMsg"
        return @{ Status = 'failed'; ErrorMessage = $errMsg; ExpiresAt = $null }
    }

    if ($null -eq $response) {
        return @{ Status = 'failed'; ErrorMessage = 'No response received from Graph API.'; ExpiresAt = $null }
    }

    $rawStatus = [string]$response.status
    $status    = switch ($rawStatus.ToLower()) {
        'granted'              { 'granted' }
        'provisioned'          { 'provisioned' }
        'pendingapproval'      { 'pendingApproval' }
        'pendingprovisioning'  { 'pendingProvisioning' }
        default                { $rawStatus }
    }

    $expiresAt = $null
    if ($response.scheduleInfo -and
        $response.scheduleInfo.expiration -and
        $response.scheduleInfo.expiration.endDateTime) {
        $expiresAt = [string]$response.scheduleInfo.expiration.endDateTime
    }

    Write-Verbose "[PIMActivator] Submit-PIMGroupActivation: status='$status', expiresAt='$expiresAt'"
    return @{ Status = $status; ErrorMessage = $null; ExpiresAt = $expiresAt }
}
