#Requires -Version 7.0

function Test-PIMDurationInput {
    <#
    .SYNOPSIS
        Validates and resolves a user-supplied duration input string for PIM activation.

    .DESCRIPTION
        Interprets a raw string (typically from interactive UI input) as a whole-number
        hour count and normalises it against the policy maximum and configured default.

        Resolution rules (applied in order):

          1. Empty or whitespace   -> use DefaultHours, Skipped=$false, no Warning.
          2. Literal "0"           -> Skipped=$true  (caller treats this assignment as skipped).
          3. Non-integer string    -> use DefaultHours with a Warning.
          4. Integer < 1 (and not the literal "0") -> use DefaultHours with a Warning.
          5. Integer > MaxHours    -> cap to MaxHours with a Warning.
          6. Integer in [1, MaxHours] -> use as-is, no Warning.

        This function never throws. Valid is always $true; the caller decides how to
        handle the Skipped flag and any Warning text.

    .PARAMETER UserInput
        The raw string supplied by the user (e.g. "8", "4", "", "abc"). An empty or
        whitespace-only value signals "use the default".

    .PARAMETER MaxHours
        The maximum number of hours permitted by policy. Must be >= 1.

    .PARAMETER DefaultHours
        The fallback number of hours used when input is absent or unparseable.
        Must be >= 1 and <= MaxHours.

    .OUTPUTS
        [hashtable] with the following keys:

            Valid    [bool]          Always $true (function never rejects outright).
            Hours    [int]           Resolved hour count to use for activation.
            Skipped  [bool]          $true when the user entered "0" to skip this assignment.
            Warning  [string|$null]  Informational message when input was overridden, else $null.

    .EXAMPLE
        $result = Test-PIMDurationInput -Input '8' -MaxHours 8 -DefaultHours 4
        # Returns: @{ Valid=$true; Hours=8; Skipped=$false; Warning=$null }

    .EXAMPLE
        $result = Test-PIMDurationInput -Input '0' -MaxHours 8 -DefaultHours 4
        # Returns: @{ Valid=$true; Hours=0; Skipped=$true; Warning=$null }

    .EXAMPLE
        $result = Test-PIMDurationInput -Input 'abc' -MaxHours 8 -DefaultHours 4
        # Returns: @{ Valid=$true; Hours=4; Skipped=$false; Warning="Invalid input 'abc'. Using default of 4 hour(s)." }

    .EXAMPLE
        $result = Test-PIMDurationInput -Input '12' -MaxHours 8 -DefaultHours 4
        # Returns: @{ Valid=$true; Hours=8; Skipped=$false; Warning="Requested 12 hour(s) exceeds maximum of 8 hour(s). Capped to 8 hour(s)." }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$UserInput,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxHours,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$DefaultHours
    )

    # Step 1 - Empty or whitespace-only: apply the default silently.
    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        return @{
            Valid   = $true
            Hours   = $DefaultHours
            Skipped = $false
            Warning = $null
        }
    }

    # Step 2 - Literal "0": the user deliberately skipped this assignment.
    if ($UserInput.Trim() -eq '0') {
        return @{
            Valid   = $true
            Hours   = 0
            Skipped = $true
            Warning = $null
        }
    }

    # Step 3 - Attempt integer parse.
    $parsedValue = 0
    $parseSucceeded = [int]::TryParse($UserInput.Trim(), [ref]$parsedValue)

    if (-not $parseSucceeded) {
        return @{
            Valid   = $true
            Hours   = $DefaultHours
            Skipped = $false
            Warning = "Invalid input '$UserInput'. Using default of $DefaultHours hour(s)."
        }
    }

    # Step 4 - Reject values below 1 (0 as a non-literal parse result, negatives, etc.).
    # Note: the literal string "0" was caught above; if we reach here with parsedValue=0,
    # the raw input was something like " 0 " with surrounding whitespace after a non-"0"
    # literal check — treat it as below-minimum.
    if ($parsedValue -lt 1) {
        return @{
            Valid   = $true
            Hours   = $DefaultHours
            Skipped = $false
            Warning = "Duration must be at least 1 hour. Using default of $DefaultHours hour(s)."
        }
    }

    # Step 5 - Cap values that exceed the policy maximum.
    if ($parsedValue -gt $MaxHours) {
        return @{
            Valid   = $true
            Hours   = $MaxHours
            Skipped = $false
            Warning = "Requested $parsedValue hour(s) exceeds maximum of $MaxHours hour(s). Capped to $MaxHours hour(s)."
        }
    }

    # Step 6 - Value is within the valid range.
    return @{
        Valid   = $true
        Hours   = $parsedValue
        Skipped = $false
        Warning = $null
    }
}
