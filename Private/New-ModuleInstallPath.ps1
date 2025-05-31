<#
.SYNOPSIS
    Creates version-specific module installation paths

.DESCRIPTION
    Internal helper function that creates the standard module installation path structure:
    InstallPath/ModuleName/Version/
    
    Also handles existence checking and Force parameter validation.

.PARAMETER InstallPath
    The base installation path

.PARAMETER ModuleName
    The name of the module

.PARAMETER ModuleVersion
    The version of the module

.PARAMETER Force
    Whether to overwrite existing installations

.EXAMPLE
    $pathInfo = New-ModuleInstallPath -InstallPath "C:\Modules" -ModuleName "MyModule" -ModuleVersion "1.0.0" -Force
    # Returns: @{ ModuleBasePath = "C:\Modules\MyModule"; DestinationPath = "C:\Modules\MyModule\1.0.0"; ShouldOverwrite = $true }

.NOTES
    This function consolidates the module path creation pattern used across
    install functions from both local and GitHub sources.
#>
function New-ModuleInstallPath {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$InstallPath,
        
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$ModuleVersion,
        
        [switch]$Force
    )
    
    # Create version-specific destination path: InstallPath/ModuleName/Version/
    $moduleBasePath = Join-Path $InstallPath $ModuleName
    $destinationPath = Join-Path $moduleBasePath $ModuleVersion
    
    # Check if module already exists
    $existsAlready = Test-Path $destinationPath
    if ($existsAlready -and -not $Force) {
        throw "Module '$ModuleName' version '$ModuleVersion' already exists at $destinationPath. Use -Force to overwrite."
    }
    
    return @{
        ModuleBasePath = $moduleBasePath
        DestinationPath = $destinationPath
        ExistsAlready = $existsAlready
        ShouldOverwrite = $Force.IsPresent -and $existsAlready
    }
}
