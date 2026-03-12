#Requires -Version 7.0

function Show-PIMAssignmentTable {
    <#
    .SYNOPSIS
        Displays a Spectre Console formatted table of eligible PIM assignments.

    .DESCRIPTION
        Renders a numbered table of PIM assignment objects using Format-SpectreTable.
        Each row shows the row number, assignment type, name, and management group
        (or a dash when not applicable). A newline is written before the table to
        provide visual separation from preceding output.

        This function produces no return value. Its sole purpose is to render UI
        output to the terminal via PwshSpectreConsole.

    .PARAMETER Assignments
        One or more assignment PSCustomObjects that conform to the standard
        PIMActivator assignment contract:
            Type            [string]  'Entra ID Role' | 'PIM Group'
            Name            [string]
            DisplayText     [string]
            ManagementGroup [string|null]

    .PARAMETER Title
        Title string rendered as the table caption.
        Default: 'Eligible PIM Assignments'

    .EXAMPLE
        $assignments = Get-PIMEligibleAssignments
        Show-PIMAssignmentTable -Assignments $assignments

    .EXAMPLE
        Show-PIMAssignmentTable -Assignments $filtered -Title 'Entra ID Role Assignments'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Assignments,

        [string]$Title = 'Eligible PIM Assignments'
    )

    Write-SpectreHost ''

    $rowNumber = 0
    $tableData = foreach ($assignment in $Assignments) {
        $rowNumber++

        $mgDisplay = if (-not [string]::IsNullOrWhiteSpace($assignment.ManagementGroup)) {
            $assignment.ManagementGroup
        }
        else {
            '-'
        }

        [PSCustomObject]@{
            '#'               = $rowNumber
            'Type'            = $assignment.Type
            'Name'            = $assignment.Name
            'Management Group' = $mgDisplay
        }
    }

    $tableData | Format-SpectreTable -Title $Title -Color 'deepskyblue1' -Border 'Rounded'
}
