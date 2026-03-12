#Requires -Version 7.0

function Show-PIMActivationSummary {
    <#
    .SYNOPSIS
        Displays a colour-coded summary table of PIM activation results.

    .DESCRIPTION
        Renders a horizontal rule followed by a Format-SpectreTable table containing
        one row per activation result. The Status column is wrapped in Spectre markup
        to colour-code each outcome:

            granted / provisioned          → green
            pendingApproval / pending*     → yellow
            failed                         → bold red
            skipped                        → grey
            anything else                  → plain white

        Below the table a one-line totals summary shows counts for activated, pending,
        and failed items.

        This function produces no return value. Its sole purpose is to render UI output
        to the terminal via PwshSpectreConsole.

    .PARAMETER Results
        One or more result PSCustomObjects as returned by Show-PIMActivationProgress,
        each having the following properties:
            Name          [string]
            Type          [string]
            Status        [string]
            DurationHours [int]
            ExpiresAt     [string|null]
            ErrorMessage  [string|null]

    .EXAMPLE
        Show-PIMActivationSummary -Results $activationResults

    .EXAMPLE
        $results = Show-PIMActivationProgress -Queue $queue -ProcessItem $block
        Show-PIMActivationSummary -Results $results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    Write-SpectreRule -Title 'Activation Summary' -Color 'deepskyblue1'

    # Count by status category (case-insensitive).
    $activated = ($Results | Where-Object { $_.Status -in @('granted', 'provisioned') }).Count
    $pending   = ($Results | Where-Object { $_.Status -like 'pending*' }).Count
    $failed    = ($Results | Where-Object { $_.Status -eq 'failed' }).Count

    # Helper: wrap a status string in the appropriate Spectre colour markup.
    $colorize = {
        param([string]$statusValue)
        switch ($statusValue.ToLower()) {
            { $_ -in @('granted', 'provisioned') }              { "[green]$statusValue[/]"; break }
            { $_ -like 'pending*' }                                { "[yellow]$statusValue[/]"; break }
            'failed'                                             { "[bold red]$statusValue[/]"; break }
            'skipped'                                            { "[grey]$statusValue[/]"; break }
            default                                              { $statusValue }
        }
    }

    # Build the table rows with markup-wrapped status.
    $tableData = foreach ($result in $Results) {
        $coloredStatus = & $colorize $result.Status

        [PSCustomObject]@{
            'Name'     = $result.Name
            'Type'     = $result.Type
            'Status'   = $coloredStatus
            'Duration' = "$($result.DurationHours)h"
        }
    }

    $tableData | Format-SpectreTable -Title 'Results' -Color 'deepskyblue1' -Border 'Rounded' -AllowMarkup

    Write-SpectreHost ''
    Write-SpectreHost "[green]Activated: $activated[/]  [yellow]Pending: $pending[/]  [bold red]Failed: $failed[/]"
}
