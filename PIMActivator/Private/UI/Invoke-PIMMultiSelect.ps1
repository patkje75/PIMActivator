#Requires -Version 7.0

function Invoke-PIMMultiSelect {
    <#
    .SYNOPSIS
        Presents a Spectre Console multi-select checkbox list for PIM assignment selection.

    .DESCRIPTION
        Extracts the DisplayText property from each supplied assignment object and
        passes the resulting list to Read-SpectreMultiSelection. The selected display
        text strings are then mapped back to their originating assignment objects, so
        the caller receives full assignment objects rather than plain strings.

        If the user confirms without selecting any items, an empty array is returned
        (never $null), so callers can safely check .Count without a null guard.

    .PARAMETER Assignments
        One or more assignment PSCustomObjects conforming to the standard PIMActivator
        assignment contract. Each object must have a non-empty DisplayText property.

    .PARAMETER PageSize
        The maximum number of items visible in the scrollable selection list at one
        time. Default: 15.

    .OUTPUTS
        [object[]]
        The assignment PSCustomObjects that correspond to the user's selection.
        Returns an empty array when nothing is selected.

    .EXAMPLE
        $selected = Invoke-PIMMultiSelect -Assignments $assignments
        if ($selected.Count -eq 0) { return }

    .EXAMPLE
        $selected = Invoke-PIMMultiSelect -Assignments $filtered -PageSize 10
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Assignments,

        [int]$PageSize = 15
    )

    # Build the display list and an index map so we can recover objects after selection.
    $displayTexts = $Assignments | ForEach-Object { $_.DisplayText }

    # Build a lookup: DisplayText -> assignment. Use a generic dictionary to handle
    # duplicate display texts safely (last one wins, which is acceptable here because
    # duplicate names are an edge case; the table view shows row numbers for disambiguation).
    $lookup = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($assignment in $Assignments) {
        $lookup[$assignment.DisplayText] = $assignment
    }

    $selectedTexts = Read-SpectreMultiSelection `
        -Title 'Select assignments to activate' `
        -Choices $displayTexts `
        -PageSize $PageSize

    # Guard against null return (some PwshSpectreConsole versions return $null on empty).
    if ($null -eq $selectedTexts) {
        return @()
    }

    # Map selected display strings back to assignment objects.
    $result = foreach ($text in $selectedTexts) {
        if ($lookup.ContainsKey($text)) {
            $lookup[$text]
        }
    }

    # Ensure we always return a proper array, never $null.
    if ($null -eq $result) {
        return @()
    }

    return @($result)
}
