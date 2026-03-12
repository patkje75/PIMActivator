#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Validation\Test-PIMJustificationInput.ps1"
}

Describe 'Test-PIMJustificationInput' {

    Context 'Empty and whitespace inputs' {

        It 'Returns Valid=$false for an empty string' {
            $result = Test-PIMJustificationInput -Justification ''
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Not -BeNullOrEmpty
            $result.Sanitized | Should -BeNullOrEmpty
        }

        It 'Returns Valid=$false for a whitespace-only string' {
            $result = Test-PIMJustificationInput -Justification '   '
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Not -BeNullOrEmpty
            $result.Sanitized | Should -BeNullOrEmpty
        }

        It 'Returns Reason containing "empty" for a null input' {
            # [string] parameter coerces $null to empty string in PowerShell 7
            $result = Test-PIMJustificationInput -Justification $null
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Match 'empty'
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Below MinLength' {

        It 'Returns Valid=$false for a 1-character string (default MinLength=3)' {
            $result = Test-PIMJustificationInput -Justification 'x'
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Match '3'
            $result.Sanitized | Should -BeNullOrEmpty
        }

        It 'Returns Valid=$false for a 2-character string (default MinLength=3)' {
            $result = Test-PIMJustificationInput -Justification 'ab'
            $result.Valid     | Should -BeFalse
            $result.Sanitized | Should -BeNullOrEmpty
        }

        It 'Returns Valid=$false when trimmed result is below MinLength after whitespace removal' {
            # "  hi  " trims to "hi" (2 chars) which is below default MinLength of 3
            $result = Test-PIMJustificationInput -Justification '  hi  '
            $result.Valid     | Should -BeFalse
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Valid inputs' {

        It 'Returns Valid=$true and Sanitized is set for a valid 5-character string' {
            $result = Test-PIMJustificationInput -Justification 'Hello'
            $result.Valid     | Should -BeTrue
            $result.Reason    | Should -BeNullOrEmpty
            $result.Sanitized | Should -Be 'Hello'
        }

        It 'Returns Valid=$true for a string exactly at MaxLength (500 chars)' {
            $exactly500 = 'A' * 500
            $result = Test-PIMJustificationInput -Justification $exactly500
            $result.Valid     | Should -BeTrue
            $result.Sanitized.Length | Should -Be 500
        }

        It 'Trims leading and trailing whitespace from Sanitized on valid input' {
            $result = Test-PIMJustificationInput -Justification '   Emergency patching   '
            $result.Valid     | Should -BeTrue
            $result.Sanitized | Should -Be 'Emergency patching'
        }
    }

    Context 'Above MaxLength' {

        It 'Returns Valid=$false for a 501-character string (default MaxLength=500)' {
            $over500 = 'B' * 501
            $result = Test-PIMJustificationInput -Justification $over500
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Match '500'
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Control character sanitization' {

        It 'Strips control characters and still returns Valid=$true when result meets MinLength' {
            # Tab (0x09), carriage return (0x0D), newline (0x0A) are control chars
            $withControls = "Emergency`t`r`npatching of prod"
            $result = Test-PIMJustificationInput -Justification $withControls
            $result.Valid | Should -BeTrue
            $result.Sanitized | Should -Not -Match '[\x00-\x1F\x7F]'
        }

        It 'Sanitized string does not contain ASCII DEL (0x7F)' {
            $withDel = "Valid justification$([char]0x7F)here"
            $result = Test-PIMJustificationInput -Justification $withDel
            $result.Valid     | Should -BeTrue
            $result.Sanitized | Should -Not -Match '\x7F'
        }

        It 'Returns Valid=$false when stripping control chars reduces length below MinLength' {
            # Input is 3 chars but 2 are control chars, leaving 1 printable char
            $controlHeavy = "$([char]0x01)$([char]0x02)x"
            $result = Test-PIMJustificationInput -Justification $controlHeavy
            $result.Valid     | Should -BeFalse
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Custom MinLength parameter' {

        It 'Accepts a string that meets a custom MinLength of 10' {
            $result = Test-PIMJustificationInput -Justification 'Exactly10c' -MinLength 10
            $result.Valid     | Should -BeTrue
            $result.Sanitized | Should -Be 'Exactly10c'
        }

        It 'Rejects a string shorter than a custom MinLength of 10' {
            $result = Test-PIMJustificationInput -Justification 'Short' -MinLength 10
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Match '10'
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Custom MaxLength parameter' {

        It 'Accepts a string that meets a custom MaxLength of 20' {
            $result = Test-PIMJustificationInput -Justification 'Exactly 20 chars!!!!' -MaxLength 20
            $result.Valid | Should -BeTrue
        }

        It 'Rejects a string exceeding a custom MaxLength of 10' {
            $result = Test-PIMJustificationInput -Justification 'This is longer than 10' -MaxLength 10
            $result.Valid     | Should -BeFalse
            $result.Reason    | Should -Match '10'
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }

    Context 'Return shape' {

        It 'Always returns a hashtable with Valid, Reason, and Sanitized keys on success' {
            $result = Test-PIMJustificationInput -Justification 'Valid input'
            $result            | Should -BeOfType [hashtable]
            $result.Keys       | Should -Contain 'Valid'
            $result.Keys       | Should -Contain 'Reason'
            $result.Keys       | Should -Contain 'Sanitized'
        }

        It 'Always returns a hashtable with Valid, Reason, and Sanitized keys on failure' {
            $result = Test-PIMJustificationInput -Justification ''
            $result            | Should -BeOfType [hashtable]
            $result.Keys       | Should -Contain 'Valid'
            $result.Keys       | Should -Contain 'Reason'
            $result.Keys       | Should -Contain 'Sanitized'
        }

        It 'Reason is $null when Valid=$true' {
            $result = Test-PIMJustificationInput -Justification 'Good justification text'
            $result.Valid  | Should -BeTrue
            $result.Reason | Should -BeNullOrEmpty
        }

        It 'Sanitized is $null when Valid=$false' {
            $result = Test-PIMJustificationInput -Justification 'x'
            $result.Valid     | Should -BeFalse
            $result.Sanitized | Should -BeNullOrEmpty
        }
    }
}
