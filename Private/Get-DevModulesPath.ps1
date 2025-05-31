<#
.SYNOPSIS
    Gets the default development modules installation path

.DESCRIPTION
    Internal function that returns the appropriate development modules path
    based on the operating system. Uses the standard PowerShell Modules directory
    so that installed modules are automatically available.

.EXAMPLE
    $path = Get-DevModulesPath
    
.NOTES
    Returns the first user-writable path from $env:PSModulePath:
    - Windows: ~/Documents/PowerShell/Modules
    - macOS/Linux: ~/.local/share/powershell/Modules
#>
function Get-DevModulesPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    # Get the first user-writable path from PSModulePath
    # This ensures modules are automatically discoverable
    $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    
    foreach ($path in $modulePaths) {
        # Skip system paths, look for user paths
        if ($path -like "*$env:HOME*" -or $path -like "*$env:USERPROFILE*") {
            return $path
        }
    }
    
    # Fallback to standard user module paths if PSModulePath doesn't contain expected paths
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell 6+ has $IsWindows automatic variable
        if ($IsWindows) { 
            return (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules')
        } else { 
            return (Join-Path $env:HOME '.local/share/powershell/Modules')
        }
    } else {
        # PowerShell 5.1 on Windows
        if ($env:OS -eq 'Windows_NT') {
            return (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules')
        } else {
            return (Join-Path $env:HOME '.local/share/powershell/Modules')
        }
    }
}
