#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Self-installation script for PoShDevModules from GitHub.

.DESCRIPTION
    This script imports the PoShDevModules module from its current development location,
    then uses the module's own Install-DevModule function to install the latest version
    from the GitHub repository "dwgeddes/PoShDevModules".
    
    The script assumes it's located in the Tools directory of the module, but includes
    error handling if it's not in the expected location.

.PARAMETER Force
    Forces the installation, overwriting any existing installation.

.PARAMETER SkipImport
    Skips importing the newly installed module after installation.

.PARAMETER InstallPath
    Custom installation path. If not specified, uses the standard PowerShell module path.

.PARAMETER Branch
    GitHub branch to install from. Defaults to 'main'.

.PARAMETER PersonalAccessToken
    GitHub Personal Access Token for private repositories or to avoid rate limiting.

.EXAMPLE
    .\SelfInstall.ps1
    Installs PoShDevModules from GitHub using default settings.

.EXAMPLE
    .\SelfInstall.ps1 -Force
    Forces installation, overwriting any existing version.

.EXAMPLE
    .\SelfInstall.ps1 -Branch "develop" -Force
    Installs from the develop branch with force.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Force,
    [switch]$SkipImport,
    [string]$InstallPath,
    [string]$Branch = 'main',
    [string]$PersonalAccessToken
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configuration
$GitHubRepo = 'dwgeddes/PoShDevModules'
$ModuleName = 'PoShDevModules'

Write-Host "🚀 PoShDevModules Self-Installation Script" -ForegroundColor Cyan
Write-Host "Repository: $GitHubRepo" -ForegroundColor Gray
Write-Host "Branch: $Branch" -ForegroundColor Gray

try {
    # Step 1: Determine script location and find module root
    Write-Host "`n📍 Determining module location..." -ForegroundColor Yellow
    
    $ScriptPath = $PSCommandPath
    if (-not $ScriptPath) {
        $ScriptPath = $MyInvocation.MyCommand.Path
    }
    
    if (-not $ScriptPath) {
        throw "Unable to determine script location. Please run this script directly, not dot-sourced."
    }
    
    $ScriptDir = Split-Path -Parent $ScriptPath
    Write-Host "Script location: $ScriptDir" -ForegroundColor Gray
    
    # Assume we're in Tools directory, but handle if we're not
    if ((Split-Path -Leaf $ScriptDir) -eq 'Tools') {
        $ModuleRoot = Split-Path -Parent $ScriptDir
        Write-Host "✅ Script correctly located in Tools directory" -ForegroundColor Green
    } else {
        Write-Warning "Script not in expected Tools directory. Attempting to locate module root..."
        
        # Try to find the module root by looking for the .psd1 file
        $CurrentDir = $ScriptDir
        $ModuleRoot = $null
        
        for ($i = 0; $i -lt 3; $i++) {
            $ManifestPath = Join-Path $CurrentDir "$ModuleName.psd1"
            if (Test-Path $ManifestPath) {
                $ModuleRoot = $CurrentDir
                break
            }
            $CurrentDir = Split-Path -Parent $CurrentDir
            if (-not $CurrentDir) { break }
        }
        
        if (-not $ModuleRoot) {
            throw "Cannot locate $ModuleName.psd1 manifest file. Please ensure this script is run from within the module directory structure."
        }
        
        Write-Host "✅ Module root found: $ModuleRoot" -ForegroundColor Green
    }
    
    # Step 2: Verify module structure
    Write-Host "`n🔍 Verifying module structure..." -ForegroundColor Yellow
    
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    $ModulePath = Join-Path $ModuleRoot "$ModuleName.psm1"
    
    if (-not (Test-Path $ManifestPath)) {
        throw "Module manifest not found at: $ManifestPath"
    }
    
    if (-not (Test-Path $ModulePath)) {
        throw "Module file not found at: $ModulePath"
    }
    
    Write-Host "✅ Module structure verified" -ForegroundColor Green
    Write-Host "  Manifest: $ManifestPath" -ForegroundColor Gray
    Write-Host "  Module: $ModulePath" -ForegroundColor Gray
    
    # Step 3: Import the current development version
    Write-Host "`n📦 Importing current development version..." -ForegroundColor Yellow
    
    # Remove any existing version to ensure clean import
    if (Get-Module $ModuleName -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing module from session..." -ForegroundColor Gray
        Remove-Module $ModuleName -Force
    }
    
    # Import the development version
    Import-Module $ManifestPath -Force -ErrorAction Stop
    Write-Host "✅ Development version imported successfully" -ForegroundColor Green
    
    # Step 4: Verify Install-DevModule function is available
    Write-Host "`n🔧 Verifying Install-DevModule function..." -ForegroundColor Yellow
    
    $InstallFunction = Get-Command Install-DevModule -ErrorAction SilentlyContinue
    if (-not $InstallFunction) {
        throw "Install-DevModule function not found. The module may not have imported correctly."
    }
    
    Write-Host "✅ Install-DevModule function available" -ForegroundColor Green
    
    # Step 5: Install from GitHub
    Write-Host "`n🌐 Installing from GitHub repository..." -ForegroundColor Yellow
    Write-Host "Repository: $GitHubRepo" -ForegroundColor Gray
    Write-Host "Branch: $Branch" -ForegroundColor Gray
    
    $InstallParams = @{
        GitHubRepo = $GitHubRepo
        Branch = $Branch
        Force = $Force.IsPresent
        SkipImport = $SkipImport.IsPresent
    }
    
    if ($InstallPath) {
        $InstallParams.InstallPath = $InstallPath
        Write-Host "Custom install path: $InstallPath" -ForegroundColor Gray
    }
    
    if ($PersonalAccessToken) {
        $InstallParams.PersonalAccessToken = $PersonalAccessToken
        Write-Host "Using Personal Access Token for GitHub authentication" -ForegroundColor Gray
    }
    
    if ($PSCmdlet.ShouldProcess("$GitHubRepo ($Branch)", "Install from GitHub")) {
        Install-DevModule @InstallParams
        Write-Host "✅ Installation completed successfully!" -ForegroundColor Green
    }
    
    # Step 6: Verification
    if (-not $SkipImport) {
        Write-Host "`n🔍 Verifying installation..." -ForegroundColor Yellow
        
        # Check if the module is available
        $InstalledModule = Get-Module $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($InstalledModule) {
            Write-Host "✅ Module installed successfully!" -ForegroundColor Green
            Write-Host "  Version: $($InstalledModule.Version)" -ForegroundColor Gray
            Write-Host "  Location: $($InstalledModule.ModuleBase)" -ForegroundColor Gray
        } else {
            Write-Warning "Module installation may have completed, but module is not visible in Get-Module -ListAvailable"
        }
    }
    
    Write-Host "`n🎉 Self-installation completed successfully!" -ForegroundColor Green
    Write-Host "The module is now installed and ready for use." -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Self-installation failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Ensure you're running this script from within the PoShDevModules directory structure" -ForegroundColor Gray
    Write-Host "2. Check that you have internet connectivity for GitHub access" -ForegroundColor Gray
    Write-Host "3. Verify that the GitHub repository 'dwgeddes/PoShDevModules' is accessible" -ForegroundColor Gray
    Write-Host "4. If using a private repository, provide a PersonalAccessToken parameter" -ForegroundColor Gray
    Write-Host "5. Try running with -Force parameter to overwrite existing installations" -ForegroundColor Gray
    
    exit 1
}
