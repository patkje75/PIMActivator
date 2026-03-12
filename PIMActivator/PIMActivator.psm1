#Requires -Version 7.0

# PIMActivator Module Loader
# Dot-sources all private functions (Helpers -> Validation -> Graph -> UI order) then Public.

# ---------------------------------------------------------------------------
# Module-scoped state
# ---------------------------------------------------------------------------

# Cached Entra ID object ID for the authenticated user.
# Populated on first Graph call; avoids repeated /me lookups within a session.
$script:PIMCachedUserId = $null

# ---------------------------------------------------------------------------
# Private function loading (strict order: Helpers -> Validation -> Graph -> UI)
# ---------------------------------------------------------------------------

foreach ($file in (Get-Item -Path "$PSScriptRoot\Private\Helpers\*.ps1" -ErrorAction SilentlyContinue)) {
    try {
        . $file.FullName
        Write-Verbose "[PIMActivator] Loaded: $($file.FullName)"
    } catch {
        Write-Error "[PIMActivator] Failed to load '$($file.FullName)': $_"
    }
}

foreach ($file in (Get-Item -Path "$PSScriptRoot\Private\Validation\*.ps1" -ErrorAction SilentlyContinue)) {
    try {
        . $file.FullName
        Write-Verbose "[PIMActivator] Loaded: $($file.FullName)"
    } catch {
        Write-Error "[PIMActivator] Failed to load '$($file.FullName)': $_"
    }
}

foreach ($file in (Get-Item -Path "$PSScriptRoot\Private\Graph\*.ps1" -ErrorAction SilentlyContinue)) {
    try {
        . $file.FullName
        Write-Verbose "[PIMActivator] Loaded: $($file.FullName)"
    } catch {
        Write-Error "[PIMActivator] Failed to load '$($file.FullName)': $_"
    }
}

foreach ($file in (Get-Item -Path "$PSScriptRoot\Private\UI\*.ps1" -ErrorAction SilentlyContinue)) {
    try {
        . $file.FullName
        Write-Verbose "[PIMActivator] Loaded: $($file.FullName)"
    } catch {
        Write-Error "[PIMActivator] Failed to load '$($file.FullName)': $_"
    }
}

# ---------------------------------------------------------------------------
# Public function loading
# ---------------------------------------------------------------------------

foreach ($file in (Get-Item -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)) {
    try {
        . $file.FullName
        Write-Verbose "[PIMActivator] Loaded: $($file.FullName)"
    } catch {
        Write-Error "[PIMActivator] Failed to load '$($file.FullName)': $_"
    }
}

# Export-ModuleMember is intentionally omitted.
# The module manifest (PIMActivator.psd1) controls the public surface via
# FunctionsToExport, CmdletsToExport, VariablesToExport, and AliasesToExport.
