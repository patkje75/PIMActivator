#Requires -Version 7.0

function Get-PIMRoleMaxDuration {
    <#
    .SYNOPSIS
        Retrieves the maximum activation duration (in hours) for an Entra ID role
        from its PIM role management policy.

    .DESCRIPTION
        Queries the Microsoft Graph roleManagementPolicyAssignments endpoint for the
        specified role definition, expands the policy and its rules, then locates the
        'Expiration_EndUser_Assignment' expiration rule to read maximumDuration.

        The ISO 8601 duration string (e.g. 'PT8H', 'PT90M') is parsed using
        ConvertFrom-PIMIso8601Duration and converted from minutes to hours (rounded
        down). If the policy cannot be retrieved, or the rule is absent, a default
        of 8 hours is returned.

    .PARAMETER RoleDefinitionId
        The Entra ID role definition GUID (e.g. for 'Global Administrator').

    .OUTPUTS
        [int] Maximum activation duration in whole hours. Minimum 1, default fallback 8.

    .EXAMPLE
        $maxHours = Get-PIMRoleMaxDuration -RoleDefinitionId $assignment.RoleDefinitionId
        Write-Verbose "Policy allows up to $maxHours hour(s) for this role."
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RoleDefinitionId
    )

    $defaultHours = 8

    $encodedFilter = "`$filter=scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$RoleDefinitionId'"
    $expand        = "`$expand=policy(`$expand=rules)"
    $uri           = "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?$encodedFilter&$expand"

    Write-Verbose "[PIMActivator] Fetching role policy for roleDefinitionId '$RoleDefinitionId'"

    try {
        $response = Invoke-PIMGraphRequest -Uri $uri

        if ($null -eq $response -or $null -eq $response.value -or $response.value.Count -eq 0) {
            Write-Verbose '[PIMActivator] Get-PIMRoleMaxDuration: No policy assignment found. Using default.'
            return $defaultHours
        }

        $assignment = $response.value[0]
        $rules      = $null

        if ($assignment.policy -and $assignment.policy.rules) {
            $rules = $assignment.policy.rules
        }

        if ($null -eq $rules) {
            Write-Verbose '[PIMActivator] Get-PIMRoleMaxDuration: Policy rules not expanded. Using default.'
            return $defaultHours
        }

        # Prefer the specific end-user assignment expiration rule
        $expirationRule = $rules | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule' -and
            $_.id            -eq 'Expiration_EndUser_Assignment'
        } | Select-Object -First 1

        # Fall back to any expiration rule with a maximumDuration
        if ($null -eq $expirationRule) {
            $expirationRule = $rules | Where-Object {
                $_.'@odata.type' -eq '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule' -and
                -not [string]::IsNullOrWhiteSpace($_.maximumDuration)
            } | Select-Object -First 1
        }

        if ($null -eq $expirationRule -or [string]::IsNullOrWhiteSpace($expirationRule.maximumDuration)) {
            Write-Verbose '[PIMActivator] Get-PIMRoleMaxDuration: No expiration rule with maximumDuration found. Using default.'
            return $defaultHours
        }

        $totalMinutes = ConvertFrom-PIMIso8601Duration -Duration $expirationRule.maximumDuration
        if ($totalMinutes -le 0) {
            Write-Verbose '[PIMActivator] Get-PIMRoleMaxDuration: Parsed duration is zero or invalid. Using default.'
            return $defaultHours
        }

        # Convert minutes to whole hours (integer division, floored)
        $hours = [int]($totalMinutes / 60)
        if ($hours -lt 1) { $hours = 1 }

        Write-Verbose "[PIMActivator] Get-PIMRoleMaxDuration: Policy maximum is $hours hour(s) (parsed from '$($expirationRule.maximumDuration)')."
        return $hours
    }
    catch {
        Write-Verbose "[PIMActivator] Get-PIMRoleMaxDuration: Unexpected error - $_. Using default."
        return $defaultHours
    }
}
