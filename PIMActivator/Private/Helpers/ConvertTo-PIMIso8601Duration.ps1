#Requires -Version 7.0

function ConvertTo-PIMIso8601Duration {
    <#
    .SYNOPSIS
        Converts a duration in minutes into an ISO 8601 PT{H}H{M}M string.

    .DESCRIPTION
        Produces a compact ISO 8601 duration string suitable for use in Microsoft
        Graph PIM API request bodies (scheduleInfo.expiration.duration). Hours are
        only included when the total is 60 minutes or more; minutes are only included
        when there is a non-zero remainder after dividing by 60.

        Examples:
            60  -> 'PT1H'
            90  -> 'PT1H30M'
            30  -> 'PT30M'
            480 -> 'PT8H'
            1   -> 'PT1M'

    .PARAMETER Minutes
        Duration in minutes. Must be between 1 and 1440 (24 hours).

    .OUTPUTS
        [string] ISO 8601 duration, e.g. 'PT8H', 'PT1H30M', 'PT30M'.

    .EXAMPLE
        ConvertTo-PIMIso8601Duration -Minutes 480
        # Returns: 'PT8H'

    .EXAMPLE
        ConvertTo-PIMIso8601Duration -Minutes 90
        # Returns: 'PT1H30M'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 1440)]
        [int]$Minutes
    )

    $hours          = [int][Math]::Floor($Minutes / 60)
    $remainingMins  = $Minutes % 60

    $result = 'PT'
    if ($hours -gt 0)         { $result += "${hours}H" }
    if ($remainingMins -gt 0) { $result += "${remainingMins}M" }

    return $result
}
