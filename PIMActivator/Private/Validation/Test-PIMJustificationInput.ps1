#Requires -Version 7.0

function Test-PIMJustificationInput {
    <#
    .SYNOPSIS
        Validates and sanitizes a PIM activation justification string.

    .DESCRIPTION
        Validates that a justification string meets the minimum and maximum length
        requirements required by Microsoft Entra PIM activation requests. Leading and
        trailing whitespace is trimmed, and control characters (ASCII 0x00-0x1F and
        0x7F) are stripped before length evaluation.

        This function never throws. All outcomes are communicated through the
        returned hashtable.

    .PARAMETER Justification
        The justification string to validate. May be null, empty, or whitespace-only,
        in which case the function returns Valid=$false.

    .PARAMETER MinLength
        Minimum number of characters required after trimming and sanitization.
        Default: 3.

    .PARAMETER MaxLength
        Maximum number of characters allowed after trimming and sanitization.
        Default: 500.

    .OUTPUTS
        [hashtable] with the following keys:

            Valid      [bool]          $true if the input passes all checks.
            Reason     [string|$null]  Human-readable failure reason, or $null on success.
            Sanitized  [string|$null]  The trimmed, control-character-free string on success,
                                       or $null on failure.

    .EXAMPLE
        $result = Test-PIMJustificationInput -Justification 'Emergency patching of prod DB'
        if (-not $result.Valid) { throw $result.Reason }
        $cleanJustification = $result.Sanitized

    .EXAMPLE
        $result = Test-PIMJustificationInput -Justification '  hi  ' -MinLength 5
        # Returns: @{ Valid=$false; Reason='Justification must be at least 5 characters.'; Sanitized=$null }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Justification,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$MinLength = 3,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxLength = 500
    )

    # Step 1 - Reject null, empty, or whitespace-only input before any processing.
    if ([string]::IsNullOrWhiteSpace($Justification)) {
        return @{
            Valid     = $false
            Reason    = 'Justification cannot be empty.'
            Sanitized = $null
        }
    }

    # Step 2 - Trim leading and trailing whitespace.
    $trimmed = $Justification.Trim()

    # Step 3 - Strip ASCII control characters (0x00-0x1F and DEL 0x7F).
    $sanitized = $trimmed -replace '[\x00-\x1F\x7F]', ''

    # Step 4 - Enforce minimum length on the sanitized string.
    if ($sanitized.Length -lt $MinLength) {
        return @{
            Valid     = $false
            Reason    = "Justification must be at least $MinLength characters."
            Sanitized = $null
        }
    }

    # Step 5 - Enforce maximum length on the sanitized string.
    if ($sanitized.Length -gt $MaxLength) {
        return @{
            Valid     = $false
            Reason    = "Justification must not exceed $MaxLength characters."
            Sanitized = $null
        }
    }

    # Step 6 - All checks passed.
    return @{
        Valid     = $true
        Reason    = $null
        Sanitized = $sanitized
    }
}
