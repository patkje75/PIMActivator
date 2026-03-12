---
name: Bug report
about: Report unexpected behavior or errors in PIMActivator
title: "[Bug] "
labels: bug
assignees: ''
---

## Describe the bug

A clear and concise description of what the bug is.

## Environment

| Field | Value |
|---|---|
| PowerShell version | <!-- paste `$PSVersionTable.PSVersion` output — must be 7.0+, Core edition --> |
| Module version | <!-- paste `(Get-Module PIMActivator).Version` output --> |
| Microsoft.Graph.Authentication version | <!-- paste `(Get-Module Microsoft.Graph.Authentication).Version` --> |
| PwshSpectreConsole version | <!-- paste `(Get-Module PwshSpectreConsole).Version` --> |
| OS | <!-- e.g. Windows 11, macOS 14, Ubuntu 22.04 --> |

## Steps to reproduce

1. Connect to Graph with: `Connect-MgGraph -Scopes ...`
2. Run: `Invoke-PIMActivation ...`
3. See error / unexpected behavior

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened. Include the full error message:

```
Paste error output here
```

## Additional context

- Does the issue reproduce with a fresh PowerShell 7+ session?
- Does the issue reproduce with `-WhatIf` (no activation requests sent)?
- Any other relevant context (tenant configuration, PIM policy settings, etc.)
