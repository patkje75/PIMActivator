#Requires -Version 7.0

function ConvertTo-PIMAssignmentObject {
    <#
    .SYNOPSIS
        Normalises a raw Graph eligibility schedule object into the standard
        PIMActivator assignment PSCustomObject.

    .DESCRIPTION
        Converts either an Entra ID roleEligibilitySchedule object (with expanded
        roleDefinition) or a PIM group privilegedAccessGroupEligibilitySchedule
        object into the shared assignment contract used by the UI layer and public
        functions.

        Assignment object contract:
            Type             [string]  'Entra ID Role' | 'PIM Group'
            Name             [string]  Display name of the role or group
            Id               [string]  Schedule object id (eligibilitySchedule.id)
            DisplayText      [string]  UI label: "{Name} (Entra ID Role)"
                                                 "{Name} (PIM Group - {member|owner})"
            SortKey          [string]  Entra: Name; PIM Group: ManagementGroup (or Name if not parseable)
            RoleDefinitionId [string]  Entra only; $null for PIM Group
            DirectoryScopeId [string]  Entra only; $null for PIM Group
            GroupId          [string]  PIM Group only; $null for Entra
            AccessId         [string]  PIM Group only ('member'|'owner'); $null for Entra
            ManagementGroup  [string]  PIM Group only (extracted from name); $null for Entra

        ManagementGroup extraction: looks for the pattern
            ^azr-pag-(mg|sub)-([^-]+)
        and returns the captured segment (e.g. 'root', 'connectivity', 'analytics').
        If the name does not match, ManagementGroup is $null and SortKey falls back
        to the group Name.

    .PARAMETER InputObject
        The raw Graph object from either Get-PIMEligibleRoles or Get-PIMEligibleGroups.

    .PARAMETER Type
        Discriminator: 'EntraRole' for Entra ID role schedules, 'PIMGroup' for group
        eligibility schedules.

    .OUTPUTS
        [PSCustomObject] following the assignment object contract described above.

    .EXAMPLE
        $roles = Get-PIMEligibleRole -UserId $me.id
        $assignments = $roles | ForEach-Object {
            ConvertTo-PIMAssignmentObject -InputObject $_ -Type EntraRole
        }

    .EXAMPLE
        $groups = Get-PIMEligibleGroup -UserId $me.id
        $assignments = $groups | ForEach-Object {
            ConvertTo-PIMAssignmentObject -InputObject $_ -Type PIMGroup
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateSet('EntraRole', 'PIMGroup')]
        [string]$Type
    )

    if ($Type -eq 'EntraRole') {
        $name = [string]$InputObject.roleDefinition.displayName

        return [PSCustomObject]@{
            Type             = 'Entra ID Role'
            Name             = $name
            Id               = [string]$InputObject.id
            DisplayText      = "$name (Entra ID Role)"
            SortKey          = $name
            RoleDefinitionId = [string]$InputObject.roleDefinitionId
            DirectoryScopeId = [string]$InputObject.directoryScopeId
            GroupId          = $null
            AccessId         = $null
            ManagementGroup  = $null
        }
    }

    # PIMGroup branch
    # Prefer the expanded group navigation property; fall back to a placeholder name
    $groupName = $null
    if ($InputObject.group -and -not [string]::IsNullOrWhiteSpace($InputObject.group.displayName)) {
        $groupName = [string]$InputObject.group.displayName
    }
    else {
        $groupName = "Group ($($InputObject.groupId))"
    }

    $accessId       = [string]$InputObject.accessId
    $managementGroup = $null

    # Extract management group segment from Azure Landing Zone naming convention
    # Pattern: azr-pag-mg-{mgName}-... or azr-pag-sub-{scopeName}-...
    if ($groupName -match '^azr-pag-(?:mg|sub)-([^-]+)') {
        $managementGroup = $Matches[1]
    }

    $sortKey = $managementGroup ?? $groupName

    return [PSCustomObject]@{
        Type             = 'PIM Group'
        Name             = $groupName
        Id               = [string]$InputObject.id
        DisplayText      = "$groupName (PIM Group - $accessId)"
        SortKey          = $sortKey
        RoleDefinitionId = $null
        DirectoryScopeId = $null
        GroupId          = [string]$InputObject.groupId
        AccessId         = $accessId
        ManagementGroup  = $managementGroup
    }
}
