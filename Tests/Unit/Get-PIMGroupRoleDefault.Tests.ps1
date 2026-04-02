#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\PIMActivator\Private\Helpers\Test-PIMPlatformScope.ps1"
    . "$PSScriptRoot\..\..\PIMActivator\Private\Helpers\Get-PIMGroupRoleDefault.ps1"
}

Describe 'Get-PIMGroupRoleDefault' {

    BeforeEach {
        # Empty platform patterns: only built-in name-based rules apply.
        # Individual contexts override this where platform-scope testing is needed.
        $script:PIMPlatformPatterns = @()
    }

    AfterEach {
        $script:PIMPlatformPatterns = @()
    }

    Context 'Rule 1: root + owner combination -> 1 hour' {

        It 'azr-pag-mg-root-owner -> 1' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-owner' | Should -Be 1
        }

        It 'azr-pag-mg-root-member-owner -> 1 (both keywords present)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-member-owner' | Should -Be 1
        }

        It 'my-root-and-owner-group -> 1' {
            Get-PIMGroupRoleDefault -GroupName 'my-root-and-owner-group' | Should -Be 1
        }
    }

    Context 'Rule 2: root only (no owner) -> 2 hours' {

        It 'azr-pag-mg-root-contributor -> 2' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-contributor' | Should -Be 2
        }

        It 'azr-pag-mg-root-reader -> 2' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-reader' | Should -Be 2
        }

        It 'prefix-root-suffix -> 2' {
            Get-PIMGroupRoleDefault -GroupName 'prefix-root-suffix' | Should -Be 2
        }
    }

    Context 'Rule 3: owner only (no root) -> 4 hours' {

        It 'azr-pag-mg-connectivity-owner -> 4 (owner, not root)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-connectivity-owner' | Should -Be 4
        }

        It 'azr-pag-sub-corp-owner -> 4' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-corp-owner' | Should -Be 4
        }
    }

    Context 'Rule 4: platform-scope contributor/reader -> 4 hours' {

        BeforeEach {
            $script:PIMPlatformPatterns = @('*-connectivity-*', '*-platform-*', '*-management-*')
        }

        It 'azr-pag-mg-connectivity-contributor -> 4 (platform scope)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-connectivity-contributor' | Should -Be 4
        }

        It 'azr-pag-mg-management-reader -> 4 (platform scope)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-management-reader' | Should -Be 4
        }

        It 'azr-pag-mg-platform-contributor -> 4 (platform scope)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-platform-contributor' | Should -Be 4
        }
    }

    Context 'Rule 5: production subscription -> 4 hours' {

        It 'azr-pag-sub-integrations-01-p-contributor -> 4' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-integrations-01-p-contributor' | Should -Be 4
        }

        It 'azr-pag-sub-integrations-01-p-developer -> 4' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-integrations-01-p-developer' | Should -Be 4
        }

        It 'azr-pag-sub-integrations-01-p-secretsofficer -> 4' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-integrations-01-p-secretsofficer' | Should -Be 4
        }

        It 'azr-pag-sub-other-02-p-reader -> 4' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-other-02-p-reader' | Should -Be 4
        }
    }

    Context 'Rule 6: landing-zone default -> 8 hours' {

        It 'azr-pag-sub-analytics-contributor -> 8' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-analytics-contributor' | Should -Be 8
        }

        It 'azr-pag-sub-corp-contributor -> 8' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-corp-contributor' | Should -Be 8
        }

        It 'some-arbitrary-group-name -> 8' {
            Get-PIMGroupRoleDefault -GroupName 'some-arbitrary-group-name' | Should -Be 8
        }

        It 'empty-ish name with no pattern match -> 8' {
            Get-PIMGroupRoleDefault -GroupName 'team-apps-contributor' | Should -Be 8
        }
    }

    Context 'Rule priority: root+owner takes precedence over root-only and owner-only' {

        It 'root+owner group does not return 2 (root-only value)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-owner' | Should -Not -Be 2
        }

        It 'root+owner group does not return 4 (owner-only value)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-owner' | Should -Not -Be 4
        }

        It 'root+owner group does not return 8 (default)' {
            Get-PIMGroupRoleDefault -GroupName 'azr-pag-mg-root-owner' | Should -Not -Be 8
        }
    }

    Context 'Output type' {

        It 'Returns an [int] not a string' {
            $result = Get-PIMGroupRoleDefault -GroupName 'azr-pag-sub-analytics-contributor'
            $result | Should -BeOfType [int]
        }
    }
}
