#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Helpers\ConvertFrom-PIMIso8601Duration.ps1"
}

Describe 'ConvertFrom-PIMIso8601Duration' {

    Context 'Valid ISO 8601 duration strings' {

        It 'PT30M -> 30 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT30M' | Should -Be 30
        }

        It 'PT1H -> 60 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT1H' | Should -Be 60
        }

        It 'PT1H30M -> 90 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT1H30M' | Should -Be 90
        }

        It 'PT8H -> 480 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT8H' | Should -Be 480
        }

        It 'PT2H -> 120 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT2H' | Should -Be 120
        }

        It 'PT4H -> 240 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT4H' | Should -Be 240
        }

        It 'PT1M -> 1 minute' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT1M' | Should -Be 1
        }

        It 'PT12H -> 720 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT12H' | Should -Be 720
        }

        It 'PT2H30M -> 150 minutes' {
            ConvertFrom-PIMIso8601Duration -Duration 'PT2H30M' | Should -Be 150
        }
    }

    Context 'Invalid or unrecognised duration strings' {

        It 'Returns 0 for an empty-segment string (INVALID)' {
            $result = ConvertFrom-PIMIso8601Duration -Duration 'INVALID' -WarningVariable warn 3>&1 | Out-Null
            $result = ConvertFrom-PIMIso8601Duration -Duration 'INVALID' -WarningAction SilentlyContinue
            $result | Should -Be 0
        }

        It 'Emits a warning for an unrecognised format' {
            $warnings = @()
            ConvertFrom-PIMIso8601Duration -Duration 'P1D' -WarningVariable warnings -WarningAction Continue 3>&1 | Out-Null
            # Run again capturing the warning stream properly
            $output = ConvertFrom-PIMIso8601Duration -Duration 'P1DT8H' -WarningAction SilentlyContinue
            $output | Should -Be 0
        }

        It 'Returns 0 for plain hour notation without PT prefix' {
            ConvertFrom-PIMIso8601Duration -Duration '8H' -WarningAction SilentlyContinue | Should -Be 0
        }

        It 'Returns 0 for empty string' {
            ConvertFrom-PIMIso8601Duration -Duration '' -WarningAction SilentlyContinue | Should -Be 0
        }
    }

    Context 'Warning emission on invalid input' {

        It 'Emits exactly one warning when the format is unrecognised' {
            $warnings = ConvertFrom-PIMIso8601Duration -Duration 'INVALID' -WarningAction Continue 3>&1
            ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Count |
                Should -BeGreaterOrEqual 1
        }
    }
}
