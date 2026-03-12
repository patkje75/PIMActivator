#Requires -Version 7.0

function Invoke-PIMActivation {
    <#
    .SYNOPSIS
        Activates eligible Microsoft Entra ID PIM roles and PIM group memberships
        through an interactive Spectre Console workflow.

    .DESCRIPTION
        Invoke-PIMActivation is the single public entry point for the PIMActivator
        module. It orchestrates a 15-step workflow that connects to Microsoft Graph,
        discovers eligible assignments, presents interactive selection and duration
        prompts, and submits activation requests — all with rich Spectre Console UI.

        Workflow summary:

          Step  1 - Render a PIM Activator title rule.
          Step  2 - Verify a Graph connection exists; throw with reconnect guidance
                    if not.
          Step  3 - Assert required Graph scopes; warn on missing optional group
                    scopes via Assert-PIMRequiredScopes.
          Step  4 - Resolve the current user identity; update the module cache.
          Step  5 - Fetch eligible Entra ID role assignments.
          Step  6 - Fetch eligible PIM group assignments (when group scopes are
                    present); merge and sort all assignments.
          Step  7 - Guard against an empty result set.
          Step  8 - Filter assignments by type via interactive Invoke-PIMTypeFilter
                    prompt.
          Step  9 - Display the filtered assignment table.
          Step 10 - Select assignments interactively via Invoke-PIMMultiSelect.
          Step 11 - Resolve justification interactively: prompt once for a single
                    assignment; or offer a Same-for-all / Different-per-assignment
                    menu when 2+ are selected.
          Step 12 - Build the per-assignment activation queue; prompt for duration
                    interactively via Invoke-PIMDurationPrompt.
          Step 13 - Apply -WhatIf ShouldProcess; collect WhatIf-skipped results.
          Step 14 - Process activations through Show-PIMActivationProgress with a
                    closure that captures runtime context.
          Step 15 - Display a summary table and return result objects to the pipeline.

        The function supports -WhatIf: when specified, no Graph activation requests
        are submitted. Each item that would have been activated is returned with
        Status = 'skipped' and ErrorMessage = 'WhatIf'.

    .OUTPUTS
        [PSCustomObject[]]
        One object per processed assignment with the following properties:

            Name          [string]       Display name of the role or group.
            Type          [string]       'Entra ID Role' or 'PIM Group'.
            Status        [string]       'granted' | 'provisioned' |
                                         'pendingApproval' | 'pendingProvisioning' |
                                         'failed' | 'skipped'
            DurationHours [int]          Resolved duration in hours.
            ExpiresAt     [string|null]  ISO 8601 expiry timestamp, or $null.
            ErrorMessage  [string|null]  Error detail when Status is 'failed', or
                                         'WhatIf' when -WhatIf was supplied.

    .EXAMPLE
        Invoke-PIMActivation

        Fully interactive mode. Prompts for type filter, assignment selection,
        justification, and per-assignment duration.

    .EXAMPLE
        Invoke-PIMActivation -WhatIf | Select-Object Name, Status

        Dry run: shows what would be activated without submitting any requests.
        Pipeline output can be inspected or formatted.

    .NOTES
        Version : 1.0.0
        Author  : PIMActivator Contributors

        Required Graph scopes (Entra ID roles only):
            RoleEligibilitySchedule.Read.Directory
            RoleAssignmentSchedule.Read.Directory
            RoleAssignmentSchedule.ReadWrite.Directory

        Additional scopes required for PIM group activation:
            PrivilegedEligibilitySchedule.Read.AzureADGroup
            PrivilegedAssignmentSchedule.Read.AzureADGroup
            PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup

        Connect example (full 7-scope set):
            Connect-MgGraph -Scopes @(
                'RoleEligibilitySchedule.Read.Directory',
                'RoleAssignmentSchedule.Read.Directory',
                'RoleAssignmentSchedule.ReadWrite.Directory',
                'PrivilegedEligibilitySchedule.Read.AzureADGroup',
                'PrivilegedAssignmentSchedule.Read.AzureADGroup',
                'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup',
                'RoleManagementPolicy.Read.Directory'
            )
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # ---------------------------------------------------------------------------
    # Step 1: Title banner
    # ---------------------------------------------------------------------------

    Write-SpectreRule -Title 'PIM Activator' -Color 'deepskyblue1'

    # ---------------------------------------------------------------------------
    # Step 2: Verify Graph connection
    # ---------------------------------------------------------------------------

    if (-not (Test-PIMGraphConnection)) {
        $connected = Invoke-PIMGraphConnect
        if (-not $connected) {
            Write-SpectreHost '[grey]Exiting PIM Activator.[/]'
            return @()
        }
    }

    # ---------------------------------------------------------------------------
    # Step 3: Assert required scopes; capture group capability flag
    # ---------------------------------------------------------------------------

    $hasGroupScopes = Assert-PIMRequiredScope

    # ---------------------------------------------------------------------------
    # Step 4: Resolve current user
    # ---------------------------------------------------------------------------

    $currentUser = Get-PIMCurrentUser
    $script:PIMCachedUserId = $currentUser.id

    # ---------------------------------------------------------------------------
    # Step 5: Fetch eligible Entra ID role assignments
    # ---------------------------------------------------------------------------

    $userId = $currentUser.id

    $rawRoles = Get-PIMEligibleRole -UserId $userId
    $roleAssignments = @(
        $rawRoles | ForEach-Object {
            ConvertTo-PIMAssignmentObject -InputObject $_ -Type 'EntraRole'
        }
    )

    # ---------------------------------------------------------------------------
    # Step 6: Fetch eligible PIM group assignments (when scopes permit)
    # ---------------------------------------------------------------------------

    $rawGroups = @()
    if ($hasGroupScopes) {
        $rawGroups = Get-PIMEligibleGroup -UserId $userId
    }

    $groupAssignments = @(
        $rawGroups | ForEach-Object {
            ConvertTo-PIMAssignmentObject -InputObject $_ -Type 'PIMGroup'
        }
    )

    # Sort group assignments by SortKey then Name for a predictable display order.
    $groupAssignments = @(
        $groupAssignments | Sort-Object -Property SortKey, Name
    )

    $allAssignments = @($roleAssignments) + @($groupAssignments)

    # ---------------------------------------------------------------------------
    # Step 7: Guard against empty result set
    # ---------------------------------------------------------------------------

    if ($allAssignments.Count -eq 0) {
        throw '[PIMActivator] No eligible PIM assignments found for this account.'
    }

    Write-SpectreHost "[grey]Found [deepskyblue1]$($allAssignments.Count)[/] eligible assignment(s)...[/]"

    # ---------------------------------------------------------------------------
    # Step 8: Determine filtered assignment set
    # ---------------------------------------------------------------------------

    $rolesCount  = @($allAssignments | Where-Object { $_.Type -eq 'Entra ID Role' }).Count
    $groupsCount = @($allAssignments | Where-Object { $_.Type -eq 'PIM Group' }).Count

    $filterResult = Invoke-PIMTypeFilter -RolesCount $rolesCount -GroupsCount $groupsCount
    $filteredAssignments = switch ($filterResult) {
        'EntraRoles' { @($allAssignments | Where-Object { $_.Type -eq 'Entra ID Role' }) }
        'PIMGroups'  { @($allAssignments | Where-Object { $_.Type -eq 'PIM Group' }) }
        default      { $allAssignments }
    }

    # ---------------------------------------------------------------------------
    # Step 10: Determine selected assignments
    # ---------------------------------------------------------------------------

    $selectedAssignments = Invoke-PIMMultiSelect -Assignments $filteredAssignments

    if ($selectedAssignments.Count -eq 0) {
        Write-SpectreHost '[yellow]No assignments selected.[/]'
        return @()
    }

    # ---------------------------------------------------------------------------
    # Step 11: Resolve justification
    # ---------------------------------------------------------------------------

    $perAssignmentJustification = $false
    $effectiveJustification     = $null

    if ($selectedAssignments.Count -eq 1) {
        # Only one assignment — no point offering a mode menu.
        $effectiveJustification = Invoke-PIMJustificationPrompt
    }
    else {
        # Two or more assignments: offer "same for all" vs "per assignment".
        $modeChoice = Read-SpectreSelection `
            -Title   'Justification' `
            -Choices @('Same for all assignments', 'Different per assignment')

        if ($modeChoice -eq 'Same for all assignments') {
            $effectiveJustification = Invoke-PIMJustificationPrompt
        }
        else {
            $perAssignmentJustification = $true
        }
    }

    # ---------------------------------------------------------------------------
    # Step 12: Build per-assignment activation queue
    # ---------------------------------------------------------------------------

    $activationQueue = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($assignment in $selectedAssignments) {

        # Resolve the policy maximum duration for this assignment.
        if ($assignment.Type -eq 'Entra ID Role') {
            $maxHours = Get-PIMRoleMaxDuration -RoleDefinitionId $assignment.RoleDefinitionId
        }
        else {
            $maxResult = Get-PIMGroupMaxDuration -GroupId $assignment.GroupId -GroupName $assignment.Name
            $maxHours  = [System.Math]::Max(1, [System.Math]::Round($maxResult.Minutes / 60))
        }

        # Resolve the effective duration for this item interactively.
        $defaultHours = Get-PIMGroupRoleDefault -GroupName $assignment.Name
        $defaultHours = [System.Math]::Min($defaultHours, $maxHours)

        $durationResult = Invoke-PIMDurationPrompt `
            -AssignmentName $assignment.Name `
            -MaxHours       $maxHours `
            -DefaultHours   $defaultHours

        $resolvedHours = $durationResult.Hours
        $itemSkipped   = $durationResult.Skipped

        if ($itemSkipped) {
            Write-Verbose "[PIMActivator] Invoke-PIMActivation: Skipping '$($assignment.Name)' at user request."
            continue
        }

        $itemJustification = if ($perAssignmentJustification) {
            Invoke-PIMJustificationPrompt -AssignmentName $assignment.Name
        }
        else {
            $effectiveJustification
        }

        $activationQueue.Add([PSCustomObject]@{
            Assignment    = $assignment
            DurationHours = $resolvedHours
            Justification = $itemJustification
        })
    }

    if ($activationQueue.Count -eq 0) {
        Write-SpectreHost '[yellow]No assignments queued for activation.[/]'
        return @()
    }

    # ---------------------------------------------------------------------------
    # Step 13: ShouldProcess / -WhatIf handling
    # ---------------------------------------------------------------------------

    $approvedQueue = [System.Collections.Generic.List[PSCustomObject]]::new()
    $results       = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($item in $activationQueue) {
        # Strip control characters from the name to prevent ShouldProcess display issues.
        $safeName = $item.Assignment.Name -replace '[\x00-\x1F\x7F\x9B]', ''

        if (-not $PSCmdlet.ShouldProcess($safeName, "Activate PIM for $($item.DurationHours)h")) {
            $results.Add([PSCustomObject]@{
                Name          = $item.Assignment.Name
                Type          = $item.Assignment.Type
                Status        = 'skipped'
                DurationHours = $item.DurationHours
                ExpiresAt     = $null
                ErrorMessage  = 'WhatIf'
            })
        }
        else {
            $approvedQueue.Add($item)
        }
    }

    if ($approvedQueue.Count -eq 0) {
        # All items were handled by WhatIf — display summary and return.
        Show-PIMActivationSummary -Results $results.ToArray()
        return $results.ToArray()
    }

    # ---------------------------------------------------------------------------
    # Step 14: Submit activations through Show-PIMActivationProgress
    # ---------------------------------------------------------------------------

    # Capture runtime variables into named locals so the closure captures them
    # without relying on $using:, which is not needed for same-thread execution.
    $capturedUserId = $userId

    $processItemBody = {
        param([PSCustomObject]$item)

        if ($item.Assignment.Type -eq 'Entra ID Role') {

            $scopeId = $item.Assignment.DirectoryScopeId ?? '/'

            $requestBody = @{
                principalId      = $capturedUserId
                roleDefinitionId = $item.Assignment.RoleDefinitionId
                directoryScopeId = $scopeId
                justification    = $item.Justification
                scheduleInfo     = @{
                    expiration = @{
                        type     = 'afterDuration'
                        duration = (ConvertTo-PIMIso8601Duration -Minutes ($item.DurationHours * 60))
                    }
                }
            }

            Protect-PIMActivationRequest -RequestBody $requestBody

            return Submit-PIMRoleActivation `
                -UserId           $capturedUserId `
                -RoleDefinitionId $item.Assignment.RoleDefinitionId `
                -DirectoryScopeId $scopeId `
                -Justification    $item.Justification `
                -DurationHours    $item.DurationHours
        }
        else {
            return Submit-PIMGroupActivation `
                -UserId        $capturedUserId `
                -GroupId       $item.Assignment.GroupId `
                -AccessId      $item.Assignment.AccessId `
                -Justification $item.Justification `
                -DurationHours $item.DurationHours
        }
    }

    # GetNewClosure captures the $captured* variables; NewBoundScriptBlock re-attaches
    # the scriptblock to this module's session state so private functions are resolved.
    $processItem = $MyInvocation.MyCommand.ScriptBlock.Module.NewBoundScriptBlock(
        $processItemBody.GetNewClosure()
    )

    $activationResults = Show-PIMActivationProgress `
        -Queue       $approvedQueue.ToArray() `
        -ProcessItem $processItem

    foreach ($r in $activationResults) {
        $results.Add($r)
    }

    # ---------------------------------------------------------------------------
    # Step 15: Summary and pipeline output
    # ---------------------------------------------------------------------------

    Show-PIMActivationSummary -Results $results.ToArray()

    return $results.ToArray()
}
