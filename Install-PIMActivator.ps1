#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the PIMActivator module to the current user's PowerShell module path.

.DESCRIPTION
    Copies the PIMActivator folder to the first writable path found in $env:PSModulePath,
    validates that all required dependencies are available, and optionally adds an
    Import-Module statement to $PROFILE.CurrentUserAllHosts so the module is loaded
    automatically in every new session.

    Supports -WhatIf to preview all actions without making changes.

.PARAMETER AddToProfile
    When specified, appends 'Import-Module PIMActivator' to $PROFILE.CurrentUserAllHosts
    if it is not already present.

.PARAMETER Force
    Overwrites an existing PIMActivator installation at the target path without prompting.

.EXAMPLE
    .\Install-PIMActivator.ps1

    Copies PIMActivator to the first writable module path. No profile modification.

.EXAMPLE
    .\Install-PIMActivator.ps1 -AddToProfile

    Installs the module and adds auto-import to the all-hosts profile.

.EXAMPLE
    .\Install-PIMActivator.ps1 -WhatIf

    Shows what would happen without making any changes.

.EXAMPLE
    .\Install-PIMActivator.ps1 -Force -AddToProfile

    Overwrites an existing installation and adds auto-import to the profile.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch] $AddToProfile,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step {
    param ([string] $Message)
    Write-Host "  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param ([string] $Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param ([string] $Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param ([string] $Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Locate the module source (PIMActivator\ next to this script)
# ---------------------------------------------------------------------------

$scriptDir  = $PSScriptRoot
$sourceDir  = Join-Path -Path $scriptDir -ChildPath 'PIMActivator'

if (-not (Test-Path -Path $sourceDir -PathType Container)) {
    Write-Fail "Source directory not found: $sourceDir"
    throw "Cannot locate the PIMActivator module source folder. Ensure Install-PIMActivator.ps1 is run from the PIMActivator directory."
}

# ---------------------------------------------------------------------------
# Find the first writable directory in $env:PSModulePath
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'PIMActivator Installer' -ForegroundColor White
Write-Host '======================' -ForegroundColor White
Write-Host ''

Write-Step 'Searching for a writable module path...'

$modulePaths  = $env:PSModulePath -split [System.IO.Path]::PathSeparator
$targetParent = $null

foreach ($candidate in $modulePaths) {
    try {
        # Expand environment variables that may appear in the path.
        $expanded = [System.Environment]::ExpandEnvironmentVariables($candidate)

        # Prefer paths that already exist; also accept paths we can create.
        if (-not (Test-Path -Path $expanded)) {
            if ($PSCmdlet.ShouldProcess($expanded, 'Create module directory')) {
                New-Item -Path $expanded -ItemType Directory -Force | Out-Null
            }
        }

        # Probe write access by attempting to create a temporary file.
        $probe = Join-Path -Path $expanded -ChildPath ([System.IO.Path]::GetRandomFileName())
        [System.IO.File]::WriteAllText($probe, '')
        Remove-Item -Path $probe -Force

        $targetParent = $expanded
        break
    }
    catch {
        # Not writable; try next candidate.
        continue
    }
}

if (-not $targetParent) {
    Write-Fail 'No writable directory found in $env:PSModulePath.'
    throw 'Installation aborted: could not find a writable module directory.'
}

Write-Success "Target module directory: $targetParent"

# ---------------------------------------------------------------------------
# Determine the versioned installation path
# ---------------------------------------------------------------------------

# Respect PowerShell's module discovery convention: <ModuleName>\<Version>\
$moduleVersion  = '1.0.0'
$moduleRootDest = Join-Path -Path $targetParent      -ChildPath 'PIMActivator'
$versionedDest  = Join-Path -Path $moduleRootDest    -ChildPath $moduleVersion

# ---------------------------------------------------------------------------
# Copy the module
# ---------------------------------------------------------------------------

Write-Step "Copying module to: $versionedDest"

if (Test-Path -Path $versionedDest) {
    if ($Force) {
        if ($PSCmdlet.ShouldProcess($versionedDest, 'Remove existing installation')) {
            Remove-Item -Path $versionedDest -Recurse -Force
        }
    }
    else {
        Write-Warn "PIMActivator $moduleVersion is already installed at '$versionedDest'."
        Write-Warn "Use -Force to overwrite the existing installation."
        return
    }
}

if ($PSCmdlet.ShouldProcess($versionedDest, 'Copy PIMActivator module')) {
    Copy-Item -Path $sourceDir -Destination $versionedDest -Recurse -Force
    Write-Success 'Module files copied.'
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

Write-Host ''
Write-Step 'Checking required dependencies...'

# Microsoft.Graph.Authentication
$mgAuth = Get-Module -Name 'Microsoft.Graph.Authentication' -ListAvailable |
          Where-Object { $_.Version -ge [version]'2.0.0' } |
          Select-Object -First 1

if ($mgAuth) {
    Write-Success "Microsoft.Graph.Authentication $($mgAuth.Version) is available."
}
else {
    Write-Warn 'Microsoft.Graph.Authentication >= 2.0.0 is NOT installed.'
    Write-Host "         Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" -ForegroundColor Gray
}

# PwshSpectreConsole
$spectre = Get-Module -Name 'PwshSpectreConsole' -ListAvailable |
           Where-Object { $_.Version -ge [version]'1.0.0' } |
           Select-Object -First 1

if ($spectre) {
    Write-Success "PwshSpectreConsole $($spectre.Version) is available."
}
else {
    Write-Warn 'PwshSpectreConsole >= 1.0.0 is NOT installed.'
    Write-Host "         Install it with: Install-Module PwshSpectreConsole -Scope CurrentUser" -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# Optional: add Import-Module to profile
# ---------------------------------------------------------------------------

if ($AddToProfile) {
    Write-Host ''
    Write-Step "Updating profile: $($PROFILE.CurrentUserAllHosts)"

    $profilePath = $PROFILE.CurrentUserAllHosts

    # Ensure the profile file and its directory exist.
    if ($PSCmdlet.ShouldProcess($profilePath, 'Ensure profile file exists')) {
        $profileDir = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType File -Force | Out-Null
        }
    }

    $importLine  = 'Import-Module PIMActivator'
    $profileContent = if (Test-Path -Path $profilePath) {
        Get-Content -Path $profilePath -Raw
    } else {
        ''
    }

    if ($profileContent -match [regex]::Escape($importLine)) {
        Write-Success "'$importLine' is already present in the profile."
    }
    else {
        if ($PSCmdlet.ShouldProcess($profilePath, "Append '$importLine'")) {
            Add-Content -Path $profilePath -Value "`n$importLine" -Encoding utf8
            Write-Success "Added '$importLine' to profile."
        }
    }
}

# ---------------------------------------------------------------------------
# Reload the module in the current session (if it was already loaded)
# ---------------------------------------------------------------------------

Write-Host ''
Write-Step 'Reloading module in the current session...'

if (Get-Module -Name 'PIMActivator') {
    if ($PSCmdlet.ShouldProcess('PIMActivator', 'Remove-Module (reload)')) {
        Remove-Module -Name 'PIMActivator' -Force
    }
}

if ($PSCmdlet.ShouldProcess('PIMActivator', 'Import-Module')) {
    try {
        Import-Module -Name 'PIMActivator' -ErrorAction Stop
        Write-Success 'PIMActivator loaded successfully in the current session.'
    }
    catch {
        Write-Warn "Could not import PIMActivator in the current session: $_"
        Write-Host "         This is expected if required modules are missing. Install dependencies and run: Import-Module PIMActivator" -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host "Run 'Invoke-PIMActivation' to start the interactive PIM activation tool." -ForegroundColor White
Write-Host ''
