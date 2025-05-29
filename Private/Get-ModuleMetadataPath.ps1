<#
.SYNOPSIS
    Gets the path to the metadata directory for installed modules

.DESCRIPTION
    Returns the path to the metadata directory for a given install path.
    This allows for consistent access to the metadata directory across the module.

.PARAMETER InstallPath
    The installation path for which to get the metadata directory

.EXAMPLE
    $metadataPath = Get-ModuleMetadataPath -InstallPath "C:\Modules"
    
.NOTES
    By default, this returns a '.metadata' subdirectory under the install path.
    This function can be overridden in tests to use a different directory name.
#>
function Get-ModuleMetadataPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InstallPath
    )
    
    if (-not $InstallPath) {
        $InstallPath = Get-DevModulesPath
    }
    
    return Join-Path $InstallPath '.metadata'
}
