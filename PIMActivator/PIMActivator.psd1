#
# Module manifest for module 'PIMActivator'
#
# Author:  PIMActivator Contributors
# Created: 2026-03-04
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'PIMActivator.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID              = 'f2c84a17-6e3b-4d09-a751-8b2f0e5c9d34'

    # Author of this module
    Author            = 'PIMActivator Contributors'

    # Company or vendor of this module
    CompanyName       = 'Community'

    # Copyright statement for this module
    Copyright         = '(c) 2026 PIMActivator Contributors. MIT License.'

    # Description of the functionality provided by this module
    Description       = 'Interactive PIM (Privileged Identity Management) activation tool for Microsoft Entra ID roles and PIM groups. PowerShell 7+ with PwshSpectreConsole UI.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        @{
            ModuleName    = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.0.0'
        },
        @{
            ModuleName    = 'PwshSpectreConsole'
            ModuleVersion = '1.0.0'
        }
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not
    # delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Invoke-PIMActivation')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not
    # delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not
    # delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also
    # contain a PSData hashtable with additional module metadata used by PowerShell Gallery.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module for module discovery in online galleries.
            Tags         = @('PIM', 'EntraID', 'AzureAD', 'PrivilegedIdentity', 'MicrosoftGraph', 'Spectre')

            # A URL to the license for this module.
            LicenseUri   = ''

            # A URL to the main website for this project.
            ProjectUri   = ''

            # Release notes for this version
            ReleaseNotes = 'Initial release. Entra ID role activation and PIM group activation via interactive Spectre Console UI.'
        }
    }
}
