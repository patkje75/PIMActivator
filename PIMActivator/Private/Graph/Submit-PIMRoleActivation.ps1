#Requires -Version 7.0

function Submit-PIMRoleActivation {
    <#
    .SYNOPSIS
        Submits a self-activation request for an Entra ID PIM role.

    .DESCRIPTION
        Posts a roleAssignmentScheduleRequest with action 'selfActivate' to the
        Microsoft Graph roleManagement/directory/roleAssignmentScheduleRequests
        endpoint. The duration is expressed as an ISO 8601 duration string
        (e.g. PT8H) converted from the supplied DurationHours parameter.

        Returns a normalised result hashtable regardless of success or failure,
        allowing the caller to process all activations in a loop without
        try/catch boilerplate.

    .PARAMETER UserId
        Entra ID object GUID of the user activating the role (principalId).

    .PARAMETER RoleDefinitionId
        GUID of the Entra ID role definition to activate.

    .PARAMETER DirectoryScopeId
        Directory scope for the activation. Defaults to '/' (tenant root).

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
        $result = Submit-PIMRoleActivation `
            -UserId          $me.id `
            -RoleDefinitionId $assignment.RoleDefinitionId `
            -Justification   'Weekly platform review' `
            -DurationHours   4

        if ($result.Status -eq 'failed') {
            Write-Warning "Activation failed: $($result.ErrorMessage)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$RoleDefinitionId,

        [string]$DirectoryScopeId = '/',

        [Parameter(Mandatory)]
        [string]$Justification,

        [Parameter(Mandatory)]
        [int]$DurationHours
    )

    $durationMinutes = $DurationHours * 60
    $isoDuration     = ConvertTo-PIMIso8601Duration -Minutes $durationMinutes

    $body = @{
        action            = 'selfActivate'
        principalId       = $UserId
        roleDefinitionId  = $RoleDefinitionId
        directoryScopeId  = $DirectoryScopeId
        justification     = $Justification
        scheduleInfo      = @{
            expiration = @{
                type     = 'afterDuration'
                duration = $isoDuration
            }
        }
    }

    $uri = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests'

    Write-Verbose "[PIMActivator] Submitting Entra ID role activation: roleDefinitionId='$RoleDefinitionId', duration='$isoDuration'"

    $response = Invoke-PIMGraphRequest -Uri $uri -Method POST -Body $body -ReturnErrorDetails

    # Structured error returned by Invoke-PIMGraphRequest
    if ($response -is [hashtable] -and $response.ContainsKey('Success') -and $response.Success -eq $false) {
        $errMsg = $response.ErrorMessage
        if ($response.ErrorDetails -and $response.ErrorDetails.message) {
            $errMsg = $response.ErrorDetails.message
        }
        Write-Verbose "[PIMActivator] Submit-PIMRoleActivation: API error - $errMsg"
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
        default                { $rawStatus }   # Pass through unknown statuses
    }

    $expiresAt = $null
    if ($response.scheduleInfo -and
        $response.scheduleInfo.expiration -and
        $response.scheduleInfo.expiration.endDateTime) {
        $expiresAt = [string]$response.scheduleInfo.expiration.endDateTime
    }

    Write-Verbose "[PIMActivator] Submit-PIMRoleActivation: status='$status', expiresAt='$expiresAt'"
    return @{ Status = $status; ErrorMessage = $null; ExpiresAt = $expiresAt }
}
