#Requires -Version 5.1

<#
.SYNOPSIS
    PoShDevModules - PowerShell module for managing development modules

.DESCRIPTION
    This module facilitates limited management of PowerShell modules from local paths 
    or Github repos without needing to publish to NuGet repositories. The purpose is 
    to make it easier to manage modules still under development.

.NOTES
    Author: David Geddes
    Version: 1.0.0
    License: MIT
#>

# Module-level variables
$script:ModuleRoot = $PSScriptRoot

# Import private functions
$Private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)

# Import public functions  
$Public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Private + $Public)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Export the public functions
Export-ModuleMember -Function @(
    'Install-DevModule',
    'Get-InstalledDevModule', 
    'Uninstall-DevModule',
    'Update-DevModule',
    'Invoke-DevModuleOperation'
)
