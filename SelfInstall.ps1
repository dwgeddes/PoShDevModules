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

Write-Information "PoShDevModules Self-Installation" -InformationAction Continue
Write-Information "================================" -InformationAction Continue
Write-Information "" -InformationAction Continue

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

Write-Information "✓ Module source validation passed" -InformationAction Continue

# Import the module from the current location
try {
    $manifestPath = Join-Path $ModuleSourcePath 'PoShDevModules.psd1'
    Import-Module $manifestPath -Force -ErrorAction Stop
    Write-Information "✓ Module imported from source directory" -InformationAction Continue
} catch {
    Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "import PoShDevModules from source" -WriteToHost
    exit 1
}

# Determine the target installation path
$TargetPath = Get-DevModulesPath

Write-Information "Target installation path: $TargetPath" -InformationAction Continue

# Check if the module is already installed
$existingModule = Get-InstalledDevModule -Name "PoShDevModules" -ErrorAction SilentlyContinue

if ($existingModule -and -not $Force) {
    Write-Information "" -InformationAction Continue
    Write-Warning "PoShDevModules is already installed at: $($existingModule.InstallPath)"
    
    # Check if running in interactive mode
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        $response = Read-Host "Do you want to update it? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Warning "Installation cancelled."
            exit 0
        }
    } else {
        Write-Information "Running in non-interactive mode - forcing update..." -InformationAction Continue
    }
    $Force = $true
}

# Install the module using itself
try {
    Write-Information "" -InformationAction Continue
    Write-Information "Installing PoShDevModules to development modules directory..." -InformationAction Continue
    
    $installParams = @{
        SourcePath = $ModuleSourcePath
        Force = $Force
    }

    $installedModule = Install-DevModule @installParams
    
    Write-Information "✓ Module installed successfully" -InformationAction Continue
    Write-Information "  Name: $($installedModule.Name)" -InformationAction Continue
    Write-Information "  Version: $($installedModule.Version)" -InformationAction Continue
    Write-Information "  Location: $($installedModule.InstallPath)" -InformationAction Continue
    
} catch {
    Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "install PoShDevModules" -WriteToHost
    exit 1
}

# Remove the old module from memory and reimport from the new location
try {
    Write-Information "" -InformationAction Continue
    Write-Information "Reimporting module from new location..." -InformationAction Continue
    
    # Remove the current module
    Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
    
    # Import from the new location using the full path
    $installedManifestPath = Join-Path $installedModule.InstallPath "PoShDevModules.psd1"
    Import-Module $installedManifestPath -Force
    
    Write-Information "✓ Module reimported from installed location" -InformationAction Continue
    
} catch {
    Write-Warning "Module was installed but failed to reimport from new location: $($_.Exception.Message)"
    Write-Warning "You can manually import it with: Import-Module PoShDevModules"
}

# Test the installation
Write-Information "" -InformationAction Continue
Write-Information "Testing installation..." -InformationAction Continue

try {
    $testModule = Get-InstalledDevModule -Name "PoShDevModules"
    if ($testModule) {
        Write-Information "✓ Installation test passed" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        Write-Information "PoShDevModules is now installed and ready to use!" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        Write-Information "Available commands:" -InformationAction Continue
        Get-Command -Module PoShDevModules | Format-Table Name, CommandType -AutoSize
        
        Write-Information "Example usage:" -InformationAction Continue
        Write-Information "  Install-DevModule -GitHubRepo 'user/repo'" -InformationAction Continue
        Write-Information "  Get-InstalledDevModule" -InformationAction Continue
        Write-Information "  Update-DevModule -Name 'ModuleName'" -InformationAction Continue
        Write-Information "  Uninstall-DevModule -Name 'ModuleName'" -InformationAction Continue
        
    } else {
        Write-Warning "Installation test failed - module not found in installed modules list"
    }
} catch {
    Write-Warning "Installation test failed: $($_.Exception.Message)"
}

Write-Information "" -InformationAction Continue
Write-Information "Installation complete!" -InformationAction Continue
