#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Example usage script for PoShDevModules

.DESCRIPTION
    This script demonstrates how to use the PoShDevModules module for managing
    PowerShell development modules.

.EXAMPLE
    # Import the module
    Import-Module ./PoShDevModules.psd1

    # Install a module from GitHub
    Install-DevModule -GitHubRepo "user/repo" -PersonalAccessToken "your_token"

    # Install a module from local path  
    Install-DevModule -SourcePath "/path/to/module"

    # List installed development modules
    Get-InstalledDevModule

    # Update a module
    Update-DevModule -Name "ModuleName"

    # Remove a module
    Remove-DevModule -Name "ModuleName"

    # Use the convenience function (equivalent to the original script)
    Invoke-DevModuleOperation -GitHubRepo "user/repo" -Force
#>

# Import the PoShDevModules module
$ModulePath = Join-Path $PSScriptRoot "PoShDevModules.psd1"
Import-Module $ModulePath -Force

Write-Host "PoShDevModules loaded successfully!" -ForegroundColor Green
Write-Host "Available commands:" -ForegroundColor Yellow

Get-Command -Module PoShDevModules | Format-Table Name, CommandType -AutoSize

Write-Host @"

Example usage:
  Install-DevModule -GitHubRepo "microsoft/PowerShell" -Force
  Get-InstalledDevModule
  Update-DevModule -Name "PowerShell"
  Remove-DevModule -Name "PowerShell"

"@ -ForegroundColor Cyan
