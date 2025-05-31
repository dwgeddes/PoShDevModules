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

# Disable progress bars to prevent hanging in non-interactive environments
$ProgressPreference = 'SilentlyContinue'

# Get private and public function files
$PrivatePath = Join-Path $PSScriptRoot 'Private'
$PublicPath = Join-Path $PSScriptRoot 'Public'

# Load private functions first
if (Test-Path $PrivatePath) {
    $PrivateFiles = Get-ChildItem -Path $PrivatePath -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $PrivateFiles) {
        try {
            Write-Verbose "Loading private function: $($file.Name)"
            . $file.FullName
        }
        catch {
            Write-Error "Failed to load private function $($file.FullName): $($_.Exception.Message)"
            throw
        }
    }
}

# Load public functions second
if (Test-Path $PublicPath) {
    $PublicFiles = Get-ChildItem -Path $PublicPath -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $PublicFiles) {
        try {
            Write-Verbose "Loading public function: $($file.Name)"
            . $file.FullName
        }
        catch {
            Write-Error "Failed to load public function $($file.FullName): $($_.Exception.Message)"
            throw
        }
    }
}

# Ensure all required functions are loaded and exported
Export-ModuleMember -Function @(
    'Install-DevModule',
    'Get-InstalledDevModule',
    'Uninstall-DevModule',
    'Update-DevModule'
)
