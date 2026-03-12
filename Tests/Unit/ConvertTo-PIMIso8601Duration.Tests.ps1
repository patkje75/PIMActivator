#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Helpers\ConvertTo-PIMIso8601Duration.ps1"
}

Describe 'ConvertTo-PIMIso8601Duration' {

    Context 'Whole-hour values (no remainder minutes)' {

        It '60 minutes -> PT1H' {
            ConvertTo-PIMIso8601Duration -Minutes 60 | Should -Be 'PT1H'
        }

        It '120 minutes -> PT2H' {
            ConvertTo-PIMIso8601Duration -Minutes 120 | Should -Be 'PT2H'
        }

        It '480 minutes -> PT8H' {
            ConvertTo-PIMIso8601Duration -Minutes 480 | Should -Be 'PT8H'
        }

        It '1440 minutes -> PT24H' {
            ConvertTo-PIMIso8601Duration -Minutes 1440 | Should -Be 'PT24H'
        }
    }

    Context 'Sub-hour values (minutes only)' {

        It '30 minutes -> PT30M' {
            ConvertTo-PIMIso8601Duration -Minutes 30 | Should -Be 'PT30M'
        }

        It '1 minute -> PT1M' {
            ConvertTo-PIMIso8601Duration -Minutes 1 | Should -Be 'PT1M'
        }

        It '45 minutes -> PT45M' {
            ConvertTo-PIMIso8601Duration -Minutes 45 | Should -Be 'PT45M'
        }
    }

    Context 'Mixed hour and minute values' {

        It '90 minutes -> PT1H30M' {
            ConvertTo-PIMIso8601Duration -Minutes 90 | Should -Be 'PT1H30M'
        }

        It '150 minutes -> PT2H30M' {
            ConvertTo-PIMIso8601Duration -Minutes 150 | Should -Be 'PT2H30M'
        }

        It '61 minutes -> PT1H1M' {
            ConvertTo-PIMIso8601Duration -Minutes 61 | Should -Be 'PT1H1M'
        }
    }

    Context 'ValidateRange enforcement' {

        It 'Throws for 0 minutes (below range)' {
            { ConvertTo-PIMIso8601Duration -Minutes 0 } | Should -Throw
        }

        It 'Throws for 1441 minutes (above range)' {
            { ConvertTo-PIMIso8601Duration -Minutes 1441 } | Should -Throw
        }
    }
}
