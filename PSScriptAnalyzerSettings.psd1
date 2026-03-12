#
# PSScriptAnalyzer settings for the PIMActivator module.
#
# IMPORTANT: PSAvoidUsingWriteHost is NOT excluded here.
# This module uses Write-SpectreHost exclusively for all console output.
# Any use of Write-Host inside the module (PIMActivator\**) is a bug and
# must be caught by the analyzer.
#
# Standalone scripts outside the module folder (e.g. Install-PIMActivator.ps1)
# may use Write-Host for installer UX; they are analyzed separately or
# excluded via .pssa inline suppressions where justified.
#

@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @()
}
