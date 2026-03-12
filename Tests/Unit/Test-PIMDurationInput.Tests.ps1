#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Validation\Test-PIMDurationInput.ps1"
}

Describe 'Test-PIMDurationInput' {

    # Baseline policy used across most tests unless overridden.
    BeforeAll {
        $script:MaxHours     = 8
        $script:DefaultHours = 4
    }

    Context 'Empty and whitespace input (use default silently)' {

        It 'Empty string returns Hours=$DefaultHours, Skipped=$false, Warning=$null' {
            $result = Test-PIMDurationInput -UserInput '' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Skipped | Should -BeFalse
            $result.Warning | Should -BeNullOrEmpty
        }

        It 'Whitespace-only string returns Hours=$DefaultHours, Skipped=$false, Warning=$null' {
            $result = Test-PIMDurationInput -UserInput '   ' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Skipped | Should -BeFalse
            $result.Warning | Should -BeNullOrEmpty
        }
    }

    Context 'Literal "0" (skip signal)' {

        It '"0" returns Skipped=$true, Hours=0, Warning=$null' {
            $result = Test-PIMDurationInput -UserInput '0' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Skipped | Should -BeTrue
            $result.Hours   | Should -Be 0
            $result.Warning | Should -BeNullOrEmpty
        }

        It '"0" surrounded by whitespace is treated as the skip signal' {
            $result = Test-PIMDurationInput -UserInput '  0  ' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Skipped | Should -BeTrue
            $result.Hours   | Should -Be 0
        }
    }

    Context 'Valid integer within range' {

        It '"4" within MaxHours=8 returns Hours=4, Warning=$null, Skipped=$false' {
            $result = Test-PIMDurationInput -UserInput '4' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be 4
            $result.Skipped | Should -BeFalse
            $result.Warning | Should -BeNullOrEmpty
        }

        It '"1" (boundary minimum) returns Hours=1, Warning=$null' {
            $result = Test-PIMDurationInput -UserInput '1' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be 1
            $result.Warning | Should -BeNullOrEmpty
        }

        It '"8" (exactly MaxHours) returns Hours=8, Warning=$null' {
            $result = Test-PIMDurationInput -UserInput '8' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be 8
            $result.Warning | Should -BeNullOrEmpty
        }
    }

    Context 'Non-parseable input (use default with Warning)' {

        It '"abc" returns Hours=$DefaultHours and Warning contains "Invalid input"' {
            $result = Test-PIMDurationInput -UserInput 'abc' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Skipped | Should -BeFalse
            $result.Warning | Should -Match 'Invalid input'
        }

        It '"abc" Warning references the bad input value' {
            $result = Test-PIMDurationInput -UserInput 'abc' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Warning | Should -Match 'abc'
        }

        It '"3.5" (fractional string) returns Hours=$DefaultHours and Warning contains "Invalid input"' {
            $result = Test-PIMDurationInput -UserInput '3.5' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Warning | Should -Match 'Invalid input'
        }

        It '"" followed by non-numeric chars returns default with warning' {
            $result = Test-PIMDurationInput -UserInput '4h' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Warning | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Value exceeds MaxHours (cap with Warning)' {

        It '"12" exceeds MaxHours=8, Hours gets capped to 8' {
            $result = Test-PIMDurationInput -UserInput '12' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:MaxHours
            $result.Skipped | Should -BeFalse
        }

        It '"12" exceeds MaxHours=8, Warning contains "exceeds maximum"' {
            $result = Test-PIMDurationInput -UserInput '12' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Warning | Should -Match 'exceeds maximum'
        }

        It 'Warning for capped input mentions both the requested and the capped value' {
            $result = Test-PIMDurationInput -UserInput '12' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Warning | Should -Match '12'
            $result.Warning | Should -Match '8'
        }
    }

    Context 'Value below 1 (not the literal skip signal "0")' {

        It '"-1" returns Hours=$DefaultHours and Warning about minimum' {
            $result = Test-PIMDurationInput -UserInput '-1' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Valid   | Should -BeTrue
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Skipped | Should -BeFalse
            $result.Warning | Should -Match '1 hour'
        }

        It '"-5" returns Hours=$DefaultHours with a minimum-hours Warning' {
            $result = Test-PIMDurationInput -UserInput '-5' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result.Hours   | Should -Be $script:DefaultHours
            $result.Warning | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Custom MaxHours and DefaultHours values' {

        It 'Custom MaxHours=2, DefaultHours=1: "3" gets capped to 2' {
            $result = Test-PIMDurationInput -UserInput '3' -MaxHours 2 -DefaultHours 1
            $result.Hours   | Should -Be 2
            $result.Warning | Should -Match 'exceeds maximum'
        }

        It 'Custom MaxHours=24, DefaultHours=8: "24" is accepted without Warning' {
            $result = Test-PIMDurationInput -UserInput '24' -MaxHours 24 -DefaultHours 8
            $result.Hours   | Should -Be 24
            $result.Warning | Should -BeNullOrEmpty
        }

        It 'Empty input with custom DefaultHours=6 returns Hours=6' {
            $result = Test-PIMDurationInput -UserInput '' -MaxHours 8 -DefaultHours 6
            $result.Hours   | Should -Be 6
            $result.Warning | Should -BeNullOrEmpty
        }
    }

    Context 'Return shape' {

        It 'Always returns a hashtable with Valid, Hours, Skipped, Warning keys on success' {
            $result = Test-PIMDurationInput -UserInput '4' -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
            $result       | Should -BeOfType [hashtable]
            $result.Keys  | Should -Contain 'Valid'
            $result.Keys  | Should -Contain 'Hours'
            $result.Keys  | Should -Contain 'Skipped'
            $result.Keys  | Should -Contain 'Warning'
        }

        It 'Valid is always $true regardless of input quality' {
            $scenarios = @('', '0', 'abc', '-1', '99', '4')
            foreach ($s in $scenarios) {
                $result = Test-PIMDurationInput -UserInput $s -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
                $result.Valid | Should -BeTrue -Because "input '$s' should always yield Valid=`$true"
            }
        }

        It 'Skipped is $false for all non-zero inputs' {
            $nonSkipInputs = @('', 'abc', '4', '-1', '12')
            foreach ($s in $nonSkipInputs) {
                $result = Test-PIMDurationInput -UserInput $s -MaxHours $script:MaxHours -DefaultHours $script:DefaultHours
                $result.Skipped | Should -BeFalse -Because "input '$s' is not the skip signal"
            }
        }
    }
}
