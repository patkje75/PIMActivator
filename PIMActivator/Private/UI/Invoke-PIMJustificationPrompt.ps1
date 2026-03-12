#Requires -Version 7.0

function Invoke-PIMJustificationPrompt {
    <#
    .SYNOPSIS
        Prompts the user for a PIM activation justification via Spectre Console.

    .DESCRIPTION
        Presents a Read-SpectreText prompt and passes the result through
        Test-PIMJustificationInput for validation and sanitization. The prompt
        loops up to three times to give the user the opportunity to correct
        invalid input. If all three attempts are exhausted, the function falls
        back to the configured default value so the caller always receives a
        usable justification string.

        This function never throws and never returns $null or an empty string.

    .PARAMETER DefaultValue
        The justification text pre-filled as the prompt default and used as the
        safe fallback after three failed validation attempts.
        Default: 'Business requirement'

    .PARAMETER AssignmentName
        When provided, the assignment name is embedded in the prompt question:
        "Enter justification for '<AssignmentName>'". When omitted, the generic
        prompt "Enter justification for activation" is used.

    .OUTPUTS
        [string]
        A validated, trimmed, control-character-free justification string.

    .EXAMPLE
        $justification = Invoke-PIMJustificationPrompt
        # Uses 'Business requirement' as the default suggestion.

    .EXAMPLE
        $justification = Invoke-PIMJustificationPrompt -DefaultValue 'Incident INC0042 remediation'

    .EXAMPLE
        $justification = Invoke-PIMJustificationPrompt -AssignmentName 'Global Administrator'
        # Question: "Enter justification for 'Global Administrator'"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$DefaultValue    = 'Business requirement',
        [string]$AssignmentName  = ''
    )

    $question = if ($AssignmentName) {
        "Enter justification for '$AssignmentName'"
    } else {
        'Enter justification for activation'
    }

    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $raw = Read-SpectreText `
            -Question      $question `
            -DefaultAnswer $DefaultValue

        $validation = Test-PIMJustificationInput -Justification $raw

        if ($validation.Valid) {
            return $validation.Sanitized
        }

        # Show the validation failure reason with a yellow warning.
        $attemptsLeft = $maxAttempts - $attempt
        if ($attemptsLeft -gt 0) {
            Write-SpectreHost "[yellow]$($validation.Reason) ($attemptsLeft attempt(s) remaining.)[/]"
        }
        else {
            Write-SpectreHost "[yellow]$($validation.Reason) Using default justification.[/]"
        }
    }

    # Safe fallback: return the default value after exhausting all attempts.
    return $DefaultValue
}
