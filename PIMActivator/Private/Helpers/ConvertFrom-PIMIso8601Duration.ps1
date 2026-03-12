#Requires -Version 7.0

function ConvertFrom-PIMIso8601Duration {
    <#
    .SYNOPSIS
        Converts an ISO 8601 time duration string into total minutes.

    .DESCRIPTION
        Parses a subset of the ISO 8601 duration format used by the Microsoft Graph
        PIM policy API: PT{H}H{M}M (hours and/or minutes only, no days, months, or
        years). Returns the total number of minutes as an integer.

        If the input does not match the expected pattern, a warning is emitted and
        0 is returned. The function does not throw.

    .PARAMETER Duration
        An ISO 8601 duration string such as 'PT30M', 'PT1H', 'PT1H30M', or 'PT8H'.

    .OUTPUTS
        [int] Total duration in minutes. Returns 0 for invalid or unrecognised input.

    .EXAMPLE
        ConvertFrom-PIMIso8601Duration -Duration 'PT8H'
        # Returns: 480

    .EXAMPLE
        ConvertFrom-PIMIso8601Duration -Duration 'PT1H30M'
        # Returns: 90

    .EXAMPLE
        ConvertFrom-PIMIso8601Duration -Duration 'PT45M'
        # Returns: 45
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Duration
    )

    if ($Duration -match '^PT(?:(\d+)H)?(?:(\d+)M)?$') {
        $hours   = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
        $minutes = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
        return ($hours * 60) + $minutes
    }

    Write-Warning "[PIMActivator] ConvertFrom-PIMIso8601Duration: Unrecognised duration format '$Duration'. Expected PT{H}H{M}M. Returning 0."
    return 0
}
