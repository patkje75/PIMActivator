#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Helpers\Test-PIMPlatformScope.ps1"
}

Describe 'Test-PIMPlatformScope' {

    BeforeEach {
        # Set the module-scoped variable used by the function under test.
        # Pester runs in the same scope as the dot-sourced function, so $script:
        # in the function resolves to this test script's scope.
        $script:PIMPlatformPatterns = @(
            '*-connectivity-*'
            '*-platform-*'
            '*-management-*'
        )
    }

    AfterEach {
        $script:PIMPlatformPatterns = @()
    }

    Context 'Group name matches a configured platform pattern' {

        It 'Returns $true for a connectivity group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-mg-connectivity-contributor' | Should -BeTrue
        }

        It 'Returns $true for a platform group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-mg-platform-owner' | Should -BeTrue
        }

        It 'Returns $true for a management group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-mg-management-reader' | Should -BeTrue
        }

        It 'Matching is case-sensitive via -like (lower matches lower)' {
            # PowerShell -like is case-insensitive by default on Windows
            Test-PIMPlatformScope -GroupName 'AZR-PAG-MG-CONNECTIVITY-CONTRIBUTOR' | Should -BeTrue
        }
    }

    Context 'Group name does not match any platform pattern' {

        It 'Returns $false for a landing-zone analytics group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-sub-analytics-contributor' | Should -BeFalse
        }

        It 'Returns $false for a landing-zone corp group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-sub-corp-reader' | Should -BeFalse
        }

        It 'Returns $false for an arbitrary name' {
            Test-PIMPlatformScope -GroupName 'some-random-group-name' | Should -BeFalse
        }
    }

    Context 'Empty platform patterns' {

        BeforeEach {
            $script:PIMPlatformPatterns = @()
        }

        It 'Returns $false when pattern list is empty - connectivity group' {
            Test-PIMPlatformScope -GroupName 'azr-pag-mg-connectivity-contributor' | Should -BeFalse
        }

        It 'Returns $false when pattern list is empty - arbitrary group' {
            Test-PIMPlatformScope -GroupName 'any-group-name' | Should -BeFalse
        }
    }

    Context 'Null platform patterns' {

        BeforeEach {
            $script:PIMPlatformPatterns = $null
        }

        It 'Returns $false when pattern variable is null' {
            Test-PIMPlatformScope -GroupName 'azr-pag-mg-connectivity-contributor' | Should -BeFalse
        }
    }
}
