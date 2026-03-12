#Requires -Version 7.0

function Invoke-PIMGraphRequest {
    <#
    .SYNOPSIS
        Wrapper around Invoke-MgGraphRequest with structured error handling.

    .DESCRIPTION
        Invokes a Microsoft Graph API request using the authenticated session from
        the Microsoft.Graph.Authentication module. Provides two error modes:
        silent (Write-Warning + return $null) or structured (return error hashtable).

        Body objects are automatically serialized to JSON with depth 10.
        Content-Type is set to 'application/json' when a body is provided.

    .PARAMETER Uri
        The full Graph API URI to call (e.g. 'https://graph.microsoft.com/v1.0/me').

    .PARAMETER Method
        The HTTP method. Defaults to 'GET'. Accepts GET, POST, PATCH, DELETE.

    .PARAMETER Body
        Optional request body. Will be serialized via ConvertTo-Json -Depth 10.

    .PARAMETER ReturnErrorDetails
        When specified, errors are returned as a structured hashtable instead of
        emitting a warning and returning $null.

        Hashtable shape:
            @{
                Success      = $false
                StatusCode   = [int|null]
                ErrorMessage = [string]
                ErrorDetails = [object|null]  # Parsed JSON error.* object
            }

    .OUTPUTS
        On success : the raw response object returned by Invoke-MgGraphRequest.
        On error   : $null (default) or a hashtable with error details (-ReturnErrorDetails).

    .EXAMPLE
        $response = Invoke-PIMGraphRequest -Uri 'https://graph.microsoft.com/v1.0/me'

    .EXAMPLE
        $result = Invoke-PIMGraphRequest `
            -Uri    'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests' `
            -Method POST `
            -Body   $bodyHashtable `
            -ReturnErrorDetails

        if ($result.Success -eq $false) {
            Write-Warning "Activation failed: $($result.ErrorMessage)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body = $null,

        [switch]$ReturnErrorDetails
    )

    $invokeParams = @{
        Uri    = $Uri
        Method = $Method
    }

    if ($null -ne $Body) {
        $invokeParams['Body']        = ($Body | ConvertTo-Json -Depth 10)
        $invokeParams['ContentType'] = 'application/json'
    }

    try {
        return Invoke-MgGraphRequest @invokeParams
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        $statusCode       = $null
        $errorDetails     = $null

        # Attempt to extract HTTP status code from the response
        if ($_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            catch {
                Write-Verbose '[PIMGraphRequest] StatusCode could not be cast from the exception response; leaving as $null.'
            }

            # Attempt to read the response body for a Graph API error object
            try {
                $responseContent = $_.Exception.Response.Content.ReadAsStringAsync().Result
                if ($responseContent) {
                    $errorJson = $responseContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($errorJson -and $errorJson.error) {
                        $errorDetails = $errorJson.error
                        # Prefer the Graph error message over the raw exception message
                        if ($errorJson.error.message) {
                            $exceptionMessage = $errorJson.error.message
                        }
                    }
                }
            }
            catch {
                Write-Verbose '[PIMGraphRequest] Failed to parse error response body; leaving as $null.'
            }
        }

        if ($ReturnErrorDetails) {
            return @{
                Success      = $false
                StatusCode   = $statusCode
                ErrorMessage = $exceptionMessage
                ErrorDetails = $errorDetails
            }
        }

        Write-Warning "[PIMActivator] Graph request failed ($Method $Uri): $exceptionMessage"
        return $null
    }
}
