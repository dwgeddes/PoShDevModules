#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installation script for PoShDevModules

.DESCRIPTION
    This script installs the PoShDevModules module to the user's PowerShell modules directory
    for easy access from any PowerShell session.

.PARAMETER Scope
    Install scope: CurrentUser or AllUsers (requires admin privileges for AllUsers)

.PARAMETER Force
    Force installation, overwriting any existing installation

.EXAMPLE
    ./Install.ps1

.EXAMPLE
    ./Install.ps1 -Scope AllUsers -Force
#>

[CmdletBinding()]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [switch]$Force
)

# Get the appropriate modules path
if ($Scope -eq 'AllUsers') {
    if ($IsWindows) {
        $ModulesPath = "$env:ProgramFiles\PowerShell\Modules"
    } else {
        $ModulesPath = "/usr/local/share/powershell/Modules"
    }
} else {
    if ($IsWindows) {
        $ModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
    } else {
        $ModulesPath = "$env:HOME/.local/share/powershell/Modules"
    }
}

$DestinationPath = Join-Path $ModulesPath "PoShDevModules"

Write-Host "Installing PoShDevModules to: $DestinationPath" -ForegroundColor Green

# Check if module already exists
if (Test-Path $DestinationPath) {
    if (-not $Force) {
        $response = Read-Host "PoShDevModules already exists at $DestinationPath. Overwrite? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item $DestinationPath -Recurse -Force
}

# Create destination directory
New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null

# Copy module files
$SourceFiles = @(
    "PoShDevModules.psd1",
    "PoShDevModules.psm1",
    "Public",
    "Private"
)

foreach ($item in $SourceFiles) {
    $sourcePath = Join-Path $PSScriptRoot $item
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $DestinationPath -Recurse -Force
        Write-Host "Copied: $item" -ForegroundColor Cyan
    } else {
        Write-Warning "Source file not found: $item"
    }
}

# Test the installation
try {
    Import-Module $DestinationPath -Force
    Write-Host "`nInstallation successful!" -ForegroundColor Green
    Write-Host "Available commands:" -ForegroundColor Yellow
    Get-Command -Module PoShDevModules | Format-Table Name, CommandType -AutoSize
    
    Write-Host "You can now use PoShDevModules from any PowerShell session:" -ForegroundColor Cyan
    Write-Host "  Import-Module PoShDevModules" -ForegroundColor White
    Write-Host "  Install-DevModule -GitHubRepo 'user/repo'" -ForegroundColor White
} catch {
    Write-Error "Installation completed but module failed to import: $($_.Exception.Message)"
    exit 1
}
