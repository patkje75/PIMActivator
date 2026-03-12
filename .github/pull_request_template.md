## Summary

<!-- Briefly describe what this PR changes and why. Link to the related issue if applicable. -->

Closes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactor / code cleanup

## Testing checklist

- [ ] `Import-Module .\PIMActivator\PIMActivator.psd1 -Force` succeeds on **PowerShell 7+** (Core)
- [ ] `Get-Command -Module PIMActivator` shows exactly **1** exported function
- [ ] Interactive flow tested (`Invoke-PIMActivation`) — PwshSpectreConsole Spectre UI renders correctly
- [ ] Non-interactive flow tested (`-Justification 'Test' -DurationHours 1`)
- [ ] `-WhatIf` runs without errors and makes no Graph API calls

## Documentation

- [ ] Comment-Based Help updated for any new or changed parameters
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] README updated if user-facing behavior changed

## Additional notes

<!-- Anything else reviewers should know: edge cases, known limitations, follow-up work. -->
