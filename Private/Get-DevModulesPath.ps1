<#
.SYNOPSIS
    Gets the default development modules installation path

.DESCRIPTION
    Internal function that returns the appropriate development modules path
    based on the operating system. This standardizes path calculation across
    all functions and eliminates code duplication.

.EXAMPLE
    $path = Get-DevModulesPath
    
.NOTES
    Returns:
    - Windows: ~/Documents/PowerShell/DevModules
    - macOS/Linux: ~/.local/share/powershell/DevModules
#>
function Get-DevModulesPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    if ($IsWindows) { 
        return (Join-Path $env:USERPROFILE 'Documents\PowerShell\DevModules')
    } else { 
        return (Join-Path $env:HOME '.local/share/powershell/DevModules')
    }
}
