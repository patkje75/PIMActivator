#Requires -Version 7.0

function Protect-PIMActivationRequest {
    <#
    .SYNOPSIS
        Validates and sanitizes a PIM activation request body before Graph API submission.

    .DESCRIPTION
        Performs structural and content validation on a hashtable that will be submitted
        as the body of a Microsoft Graph PIM activation request. On any validation
        failure the function throws a terminating error with a descriptive message so
        the caller can surface it cleanly without wrapping every check individually.

        Validations performed (in order):

          1. principalId  - Must be present and a valid GUID.
          2. roleDefinitionId (if present) - Must be a valid GUID.
          3. groupId (if present) - Must be a valid GUID.
          4. justification - Validated and sanitized via Test-PIMJustificationInput.
                             The hashtable's justification key is updated in place with
                             the sanitized value on success.
          5. scheduleInfo.expiration.duration (if present) - Must match the ISO 8601
             duration subset accepted by the Graph PIM API: PT<n>H, PT<n>H<n>M, or
             PT<n>M (e.g. "PT8H", "PT30M", "PT1H30M").

        The function does NOT call Graph; it only validates the shape and content of
        the request body before it leaves the caller.

    .PARAMETER RequestBody
        The hashtable request body to validate. Expected keys (Graph PIM schema):

            principalId              [string] - Required. Entra object ID of the user.
            roleDefinitionId         [string] - Optional. Role definition GUID (role activation).
            groupId                  [string] - Optional. PIM group GUID (group activation).
            justification            [string] - Required. Activation justification text.
            scheduleInfo             [hashtable] - Optional. Activation schedule information.
              expiration             [hashtable]
                duration             [string] - ISO 8601 duration, e.g. "PT8H".

    .OUTPUTS
        [hashtable] The validated and sanitized request body (same object reference,
        with justification updated in place).

    .NOTES
        Throws a terminating error (using the -ErrorAction Stop pattern internally)
        on any validation failure. The caller should wrap this call in try/catch when
        a non-terminating failure path is preferred.

    .EXAMPLE
        $body = @{
            principalId      = '00000000-0000-0000-0000-000000000001'
            roleDefinitionId = '00000000-0000-0000-0000-000000000002'
            justification    = 'Emergency access for incident response'
            scheduleInfo     = @{
                expiration = @{ type = 'AfterDuration'; duration = 'PT8H' }
            }
        }
        $validatedBody = Protect-PIMActivationRequest -RequestBody $body

    .EXAMPLE
        try {
            $clean = Protect-PIMActivationRequest -RequestBody $requestBody
        }
        catch {
            Write-Warning "Request validation failed: $_"
            return
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$RequestBody
    )

    # ---------------------------------------------------------------------------
    # 1 - principalId: required, must be a valid GUID.
    # ---------------------------------------------------------------------------
    $principalId = $RequestBody['principalId']
    if ([string]::IsNullOrWhiteSpace($principalId)) {
        throw "principalId is required and must not be empty."
    }

    $guidRef = [System.Guid]::Empty
    if (-not [System.Guid]::TryParse($principalId, [ref]$guidRef)) {
        throw "principalId '$principalId' is not a valid GUID."
    }

    # ---------------------------------------------------------------------------
    # 2 - roleDefinitionId: optional, but must be a valid GUID when present.
    # ---------------------------------------------------------------------------
    if ($RequestBody.ContainsKey('roleDefinitionId') -and
        -not [string]::IsNullOrWhiteSpace($RequestBody['roleDefinitionId'])) {

        $roleId = $RequestBody['roleDefinitionId']
        $guidRef = [System.Guid]::Empty
        if (-not [System.Guid]::TryParse($roleId, [ref]$guidRef)) {
            throw "roleDefinitionId '$roleId' is not a valid GUID."
        }
    }

    # ---------------------------------------------------------------------------
    # 3 - groupId: optional, but must be a valid GUID when present.
    # ---------------------------------------------------------------------------
    if ($RequestBody.ContainsKey('groupId') -and
        -not [string]::IsNullOrWhiteSpace($RequestBody['groupId'])) {

        $groupId = $RequestBody['groupId']
        $guidRef = [System.Guid]::Empty
        if (-not [System.Guid]::TryParse($groupId, [ref]$guidRef)) {
            throw "groupId '$groupId' is not a valid GUID."
        }
    }

    # ---------------------------------------------------------------------------
    # 4 - justification: validated and sanitized; RequestBody updated in place.
    # ---------------------------------------------------------------------------
    $justificationResult = Test-PIMJustificationInput -Justification $RequestBody['justification']
    if (-not $justificationResult.Valid) {
        throw "Invalid justification: $($justificationResult.Reason)"
    }
    $RequestBody['justification'] = $justificationResult.Sanitized

    # ---------------------------------------------------------------------------
    # 5 - scheduleInfo.expiration.duration: optional ISO 8601 subset validation.
    #     Accepted patterns: PT<n>H  |  PT<n>H<n>M  |  PT<n>M
    #     Examples: PT8H, PT30M, PT1H30M
    # ---------------------------------------------------------------------------
    $scheduleInfo = $RequestBody['scheduleInfo']
    if ($null -ne $scheduleInfo -and $scheduleInfo -is [hashtable]) {
        $expiration = $scheduleInfo['expiration']
        if ($null -ne $expiration -and $expiration -is [hashtable]) {
            $duration = $expiration['duration']
            if (-not [string]::IsNullOrWhiteSpace($duration)) {
                # Regex covers: PT<n>H, PT<n>H<n>M, PT<n>M
                if ($duration -notmatch '^PT\d+H(\d+M)?$|^PT\d+M$') {
                    throw "Invalid duration format '$duration'. Expected ISO 8601 like 'PT8H' or 'PT30M'."
                }
            }
        }
    }

    return $RequestBody
}
