@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PoShDevModules.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a8c9f2e1-5b4d-4a3c-9e8f-1a2b3c4d5e6f'

    # Author of this module
    Author = 'David Geddes'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2025 David Geddes. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Facilitates limited management of PowerShell modules from local paths or Github repos without needing to publish to NuGet repositories. The purpose is to make it easier to manage modules still under development.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Install-DevModule',
        'Get-InstalledDevModule', 
        'Remove-DevModule',
        'Update-DevModule',
        'Invoke-DevModuleOperation'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('PowerShell', 'Module', 'Development', 'GitHub', 'DevOps')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/dgeddes/PoShDevModules/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/dgeddes/PoShDevModules'

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of PoShDevModules - PowerShell module for managing development modules from local paths and GitHub repositories.'
        }
    }
}
