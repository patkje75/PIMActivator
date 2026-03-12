#Requires -Version 7.0

function Show-PIMActivationProgress {
    <#
    .SYNOPSIS
        Processes each PIM activation item with per-item Spectre Console status feedback.

    .DESCRIPTION
        Iterates the activation queue sequentially, displaying a status line before
        each item is processed and a colour-coded result line immediately after.
        The ProcessItem script block supplied by the caller performs the actual Graph
        API submission; this function is responsible only for visual feedback and
        result collection.

        Processing is intentionally sequential. Parallel execution, if required, is
        the responsibility of the calling function (Invoke-PIMActivation). Running
        items in parallel from inside this function would prevent reliable per-item
        status display and make error attribution harder.

        Each queue item is expected to have:
            .Assignment   PSCustomObject  Standard PIMActivator assignment contract.
            .DurationHours  [int]         Resolved activation duration in hours.

        The ProcessItem script block receives one queue item as its sole argument and
        must return a hashtable with:
            Status        [string]  e.g. 'granted', 'pendingApproval', 'failed', 'skipped'
            ExpiresAt     [string|null]  ISO 8601 timestamp or $null
            ErrorMessage  [string|null]  Populated when Status is 'failed'

    .PARAMETER Queue
        One or more activation queue items to process.

    .PARAMETER ProcessItem
        A script block that accepts a single queue item and returns the activation
        result hashtable described above. Provided by Invoke-PIMActivation.

    .OUTPUTS
        [object[]]
        An array of PSCustomObjects, one per queue item, with properties:
            Name          [string]
            Type          [string]
            Status        [string]
            DurationHours [int]
            ExpiresAt     [string|null]
            ErrorMessage  [string|null]

    .EXAMPLE
        $results = Show-PIMActivationProgress -Queue $activationQueue -ProcessItem {
            param($item)
            Submit-PIMRoleActivation -Assignment $item.Assignment -DurationHours $item.DurationHours
        }

    .EXAMPLE
        $results = Show-PIMActivationProgress -Queue $queue -ProcessItem $submitBlock
        $results | Where-Object { $_.Status -eq 'failed' } | ForEach-Object {
            Write-SpectreHost "[bold red]Failed: $($_.Name) — $($_.ErrorMessage)[/]"
        }
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Queue,

        [Parameter(Mandatory)]
        [scriptblock]$ProcessItem
    )

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($item in $Queue) {
        # Escape the name for safe use in Spectre markup.
        $escapedName = try {
            Get-SpectreEscapedText -Text $item.Assignment.Name
        }
        catch {
            $item.Assignment.Name
        }

        # Show a "working" indicator before the API call.
        Write-SpectreHost "[deepskyblue1]Activating: $escapedName ($($item.DurationHours)h)...[/]"

        # Invoke the caller-supplied processing logic.
        $activationResult = $null
        try {
            $activationResult = & $ProcessItem $item
        }
        catch {
            $activationResult = @{
                Status       = 'failed'
                ExpiresAt    = $null
                ErrorMessage = $_.Exception.Message
            }
        }

        # Render a colour-coded result line.
        $statusMarkup = switch ($activationResult.Status.ToLower()) {
            { $_ -in @('granted', 'provisioned') } {
                "[green]Activated: $escapedName[/]"
            }
            { $_ -like 'pending*' } {
                "[yellow]Pending approval: $escapedName[/]"
            }
            'skipped' {
                "[grey]Skipped: $escapedName[/]"
            }
            'failed' {
                $escapedError = try {
                    Get-SpectreEscapedText -Text $activationResult.ErrorMessage
                }
                catch {
                    $activationResult.ErrorMessage
                }
                "[bold red]Failed: $escapedName — $escapedError[/]"
            }
            default {
                "[grey]$($activationResult.Status): $escapedName[/]"
            }
        }

        Write-SpectreHost $statusMarkup

        $results.Add([PSCustomObject]@{
            Name          = $item.Assignment.Name
            Type          = $item.Assignment.Type
            Status        = $activationResult.Status
            DurationHours = $item.DurationHours
            ExpiresAt     = $activationResult.ExpiresAt
            ErrorMessage  = $activationResult.ErrorMessage
        })
    }

    return $results.ToArray()
}
