#Requires -Version 7.0

function Get-PIMGroupMaxDuration {
    <#
    .SYNOPSIS
        Retrieves the maximum activation duration for a PIM group from its role
        management policy.

    .DESCRIPTION
        Queries the Microsoft Graph roleManagementPolicyAssignments endpoint scoped
        to the given group (scopeType 'Group'), expands the policy and its rules,
        then locates the 'Expiration_EndUser_Assignment' expiration rule.

        The ISO 8601 duration string is parsed via ConvertFrom-PIMIso8601Duration.
        If the API returns a 403 Forbidden (e.g. the caller lacks
        PrivilegedAssignmentSchedule.Read.AzureADGroup), the error is logged at
        Verbose level and the function falls back gracefully to Get-PIMGroupRoleDefault.

        Any other error also triggers the fallback.

    .PARAMETER GroupId
        The Entra ID object GUID of the PIM-managed group.

    .PARAMETER GroupName
        The display name of the group. Used as input to Get-PIMGroupRoleDefault
        when policy lookup fails or returns no data.

    .OUTPUTS
        [hashtable] with keys:
            Minutes    [int]   Maximum activation duration in minutes.
            FromPolicy [bool]  $true if the value was read from the Graph policy;
                               $false if it is a hardcoded default.

    .EXAMPLE
        $duration = Get-PIMGroupMaxDuration -GroupId $groupId -GroupName $groupName
        Write-Verbose "Max duration: $($duration.Minutes) minute(s) (from policy: $($duration.FromPolicy))"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    # Helper closure: return a fallback result based on group name heuristics
    $fallback = {
        $defaultHours   = Get-PIMGroupRoleDefault -GroupName $GroupName
        $defaultMinutes = $defaultHours * 60
        Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: Using default $defaultHours hour(s) ($defaultMinutes minutes) for '$GroupName'."
        return @{ Minutes = $defaultMinutes; FromPolicy = $false }
    }

    $encodedFilter = "`$filter=scopeId eq '$GroupId' and scopeType eq 'Group'"
    $expand        = "`$expand=policy(`$expand=rules)"
    $uri           = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?$encodedFilter&$expand"

    Write-Verbose "[PIMActivator] Fetching group policy for '$GroupName' (id: '$GroupId')"

    $result = Invoke-PIMGraphRequest -Uri $uri -ReturnErrorDetails

    # Handle structured error response
    if ($result -is [hashtable] -and $result.ContainsKey('Success') -and $result.Success -eq $false) {
        if ($result.StatusCode -eq 403) {
            Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: 403 Forbidden for group '$GroupName'. Caller may lack PrivilegedAssignmentSchedule scope."
        }
        else {
            Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: Graph error (HTTP $($result.StatusCode ?? 'unknown')) for '$GroupName': $($result.ErrorMessage)"
        }
        return & $fallback
    }

    if ($null -eq $result -or $null -eq $result.value -or $result.value.Count -eq 0) {
        Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: No policy assignment found for group '$GroupName'."
        return & $fallback
    }

    $assignment = $result.value[0]
    $rules      = $null

    if ($assignment.policy -and $assignment.policy.rules) {
        $rules = $assignment.policy.rules
    }

    if ($null -eq $rules) {
        Write-Verbose '[PIMActivator] Get-PIMGroupMaxDuration: Policy rules not present in response.'
        return & $fallback
    }

    # Prefer the specific end-user assignment expiration rule
    $expirationRule = $rules | Where-Object {
        $_.'@odata.type' -eq '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule' -and
        $_.id            -eq 'Expiration_EndUser_Assignment'
    } | Select-Object -First 1

    # Fall back to any expiration rule that carries maximumDuration
    if ($null -eq $expirationRule) {
        $expirationRule = $rules | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule' -and
            -not [string]::IsNullOrWhiteSpace($_.maximumDuration)
        } | Select-Object -First 1
    }

    if ($null -eq $expirationRule -or [string]::IsNullOrWhiteSpace($expirationRule.maximumDuration)) {
        Write-Verbose '[PIMActivator] Get-PIMGroupMaxDuration: No usable expiration rule found in policy.'
        return & $fallback
    }

    $totalMinutes = ConvertFrom-PIMIso8601Duration -Duration $expirationRule.maximumDuration
    if ($totalMinutes -le 0) {
        Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: Parsed duration '$($expirationRule.maximumDuration)' yielded zero minutes."
        return & $fallback
    }

    Write-Verbose "[PIMActivator] Get-PIMGroupMaxDuration: Policy maximum is $totalMinutes minute(s) for '$GroupName'."
    return @{ Minutes = $totalMinutes; FromPolicy = $true }
}
