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
    Description = 'PowerShell module for managing development modules from local paths and GitHub repositories with version control and cross-platform support. Simplifies development workflows by providing standardized module installation, updating, and tracking capabilities.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-InstalledDevModule',
        'Install-DevModule',
        'Uninstall-DevModule',
        'Update-DevModule'
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
            Tags = @('PowerShell', 'Module', 'Development', 'GitHub', 'DevOps', 'LocalModules', 'VersionControl', 'CrossPlatform')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/dgeddes/PoShDevModules/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/dgeddes/PoShDevModules'

            # ReleaseNotes of this module
            ReleaseNotes = @'
Initial release of PoShDevModules v1.0.0

Features:
- Install PowerShell modules from local development paths
- Install modules directly from GitHub repositories  
- Automatic version management with side-by-side installations
- Cross-platform support (Windows, macOS, Linux)
- Update tracking from original sources
- Comprehensive metadata management
- Complete test suite with 10/10 workflow tests passing

Core Functions:
- Install-DevModule: Install from local path or GitHub
- Get-InstalledDevModule: List and query installed modules
- Update-DevModule: Update from original source
- Uninstall-DevModule: Clean removal with metadata cleanup

Perfect for PowerShell module developers who need to manage modules under active development without publishing to galleries.
'@
        }
    }
}
