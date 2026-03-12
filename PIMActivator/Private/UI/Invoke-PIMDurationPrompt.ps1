#Requires -Version 7.0

function Invoke-PIMDurationPrompt {
    <#
    .SYNOPSIS
        Prompts the user for a PIM activation duration via Spectre Console.

    .DESCRIPTION
        Builds a question string that embeds the assignment name (safely escaped for
        Spectre markup) and the policy maximum, then passes the user's input through
        Test-PIMDurationInput for resolution and normalisation.

        Entering 0 signals that the user wants to skip this particular assignment;
        the returned hashtable will have Skipped=$true in that case. Any warnings
        from the validation layer (capped values, unparseable input) are surfaced to
        the user as yellow markup lines before the function returns.

        This function never throws and always returns a hashtable with both Hours
        and Skipped populated.

    .PARAMETER AssignmentName
        The display name of the assignment being configured. This is embedded in the
        prompt question. The name is escaped via Get-SpectreEscapedText before being
        used in markup strings.

    .PARAMETER MaxHours
        The maximum number of hours permitted by the assignment's PIM policy.
        Must be 1 or greater.

    .PARAMETER DefaultHours
        The default hour count to pre-fill in the prompt and to fall back to when the
        user's input is absent or invalid. Must be 1 or greater and no larger than
        MaxHours.

    .OUTPUTS
        [hashtable] with keys:
            Hours   [int]   Resolved activation duration in hours.
            Skipped [bool]  $true when the user entered 0 to skip this assignment.

    .EXAMPLE
        $duration = Invoke-PIMDurationPrompt -AssignmentName 'Global Administrator' -MaxHours 8 -DefaultHours 4
        if ($duration.Skipped) { continue }
        $hours = $duration.Hours

    .EXAMPLE
        $duration = Invoke-PIMDurationPrompt -AssignmentName $a.Name -MaxHours $policy.MaxHours -DefaultHours 2
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$AssignmentName,

        [Parameter(Mandatory)]
        [int]$MaxHours,

        [Parameter(Mandatory)]
        [int]$DefaultHours
    )

    # Escape the assignment name so any brackets or other Spectre markup characters
    # in role/group names do not corrupt the rendered prompt or status lines.
    $escapedName = try {
        Get-SpectreEscapedText -Text $AssignmentName
    }
    catch {
        $AssignmentName
    }

    $question = "Duration for '$escapedName' (1-${MaxHours}h, 0=skip)"

    $rawInput = Read-SpectreText `
        -Question $question `
        -DefaultAnswer "$MaxHours"

    $result = Test-PIMDurationInput `
        -UserInput $rawInput `
        -MaxHours $MaxHours `
        -DefaultHours $DefaultHours

    # Surface any normalisation warnings so the user knows their value was adjusted.
    if (-not [string]::IsNullOrWhiteSpace($result.Warning)) {
        Write-SpectreHost "[yellow]$($result.Warning)[/]"
    }

    if ($result.Skipped) {
        Write-SpectreHost "[grey]Skipping: $escapedName[/]"
    }

    return @{
        Hours   = $result.Hours
        Skipped = $result.Skipped
    }
}
