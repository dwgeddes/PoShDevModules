#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Self-installation script for PoShDevModules

.DESCRIPTION
    This script uses PoShDevM) catch {
    Write-Warning "Module was installed but failed to reimport from new location: $($_.Exception.Message)"
    Write-Host "You can manually import it with: Import-Module PoShDevModules" -ForegroundColor Yellow
}es to install itself to the proper development modules
    directory (~/.local/share/powershell/DevModules on macOS/Linux, 
    ~/Documents/PowerShell/DevModules on Windows) and then reimports the module 
    from the new location.

.PARAMETER Force
    Force installation, overwriting any existing installation

.EXAMPLE
    ./SelfInstall.ps1

.EXAMPLE
    ./SelfInstall.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Get the directory where this script is located (should be the module root)
$ModuleSourcePath = Split-Path $MyInvocation.MyCommand.Path -Parent

# Source required helper functions
. (Join-Path $ModuleSourcePath 'Private\Get-DevModulesPath.ps1')
. (Join-Path $ModuleSourcePath 'Private\Invoke-StandardErrorHandling.ps1')

Write-Host "PoShDevModules Self-Installation" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

# Validate that we're in the correct directory (check for key files)
$RequiredFiles = @(
    'PoShDevModules.psd1',
    'PoShDevModules.psm1',
    'Public',
    'Private'
)

foreach ($file in $RequiredFiles) {
    $path = Join-Path $ModuleSourcePath $file
    if (-not (Test-Path $path)) {
        try {
            throw "Required file/directory not found: $file. Please run this script from the PoShDevModules root directory."
        } catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "validate module source directory" -WriteToHost
            exit 1
        }
    }
}

Write-Host "✓ Module source validation passed" -ForegroundColor Green

# Import the module from the current location
try {
    $manifestPath = Join-Path $ModuleSourcePath 'PoShDevModules.psd1'
    Import-Module $manifestPath -Force -ErrorAction Stop
    Write-Host "✓ Module imported from source directory" -ForegroundColor Green
} catch {
    Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "import PoShDevModules from source" -WriteToHost
    exit 1
}

# Determine the target installation path
$TargetPath = Get-DevModulesPath

Write-Host "Target installation path: $TargetPath" -ForegroundColor Cyan

# Check if the module is already installed
$existingModule = Get-InstalledDevModule -Name "PoShDevModules" -InstallPath (Split-Path $TargetPath -Parent) -ErrorAction SilentlyContinue

if ($existingModule -and -not $Force) {
    Write-Host ""
    Write-Host "PoShDevModules is already installed at: $($existingModule.InstallPath)" -ForegroundColor Yellow
    $response = Read-Host "Do you want to update it? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    $Force = $true
}

# Install the module using itself
try {
    Write-Host ""
    Write-Host "Installing PoShDevModules to development modules directory..." -ForegroundColor Cyan
    
    $installParams = @{
        GitHubRepo = "dwgeddes/PoShDevModules"
        #SourcePath = $ModuleSourcePath
        Force = $Force
    }

    $installedModule = Install-DevModule @installParams
    
    Write-Host "✓ Module installed successfully" -ForegroundColor Green
    Write-Host "  Name: $($installedModule.Name)" -ForegroundColor White
    Write-Host "  Version: $($installedModule.Version)" -ForegroundColor White
    Write-Host "  Location: $($installedModule.InstallPath)" -ForegroundColor White
    
} catch {
    Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "install PoShDevModules" -WriteToHost
    exit 1
}

# Remove the old module from memory and reimport from the new location
try {
    Write-Host ""
    Write-Host "Reimporting module from new location..." -ForegroundColor Cyan
    
    # Remove the current module
    Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
    
    # Import from the new location
    Import-Module PoShDevModules -Force
    
    Write-Host "✓ Module reimported from installed location" -ForegroundColor Green
    
} catch {
    Write-Warning "Module was installed but failed to reimport from new location: $($_.Exception.Message)"
    Write-Host "You can manually import it with: Import-Module PoShDevModules" -ForegroundColor Yellow
}

# Test the installation
Write-Host ""
Write-Host "Testing installation..." -ForegroundColor Cyan

try {
    $testModule = Get-InstalledDevModule -Name "PoShDevModules"
    if ($testModule) {
        Write-Host "✓ Installation test passed" -ForegroundColor Green
        Write-Host ""
        Write-Host "PoShDevModules is now installed and ready to use!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Available commands:" -ForegroundColor Yellow
        Get-Command -Module PoShDevModules | Format-Table Name, CommandType -AutoSize
        
        Write-Host "Example usage:" -ForegroundColor Cyan
        Write-Host "  Install-DevModule -GitHubRepo 'user/repo'" -ForegroundColor White
        Write-Host "  Get-InstalledDevModule" -ForegroundColor White
        Write-Host "  Update-DevModule -Name 'ModuleName'" -ForegroundColor White
        Write-Host "  Uninstall-DevModule -Name 'ModuleName'" -ForegroundColor White
        
    } else {
        Write-Warning "Installation test failed - module not found in installed modules list"
    }
} catch {
    Write-Warning "Installation test failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-LogMessage "Installation complete!" "Success"
