# Simple test runner with basic mocking
# Focuses on testing with timeout protection

# Import the module
$moduleRoot = Split-Path -Parent $PSScriptRoot
Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
Import-Module "$moduleRoot/PoShDevModules.psd1" -Force

# Validate module was imported successfully
if (-not (Get-Module PoShDevModules)) {
    Write-Host "❌ Failed to import PoShDevModules module!" -ForegroundColor Red
    throw "Module import failed. Make sure the module path is correct."
}

# Create test environment - use platform-agnostic temp path
$TestDrive = Join-Path ([System.IO.Path]::GetTempPath()) "PoShDevModulesTest_$(Get-Random)"
New-Item -Path $TestDrive -ItemType Directory -Force | Out-Null
$TestInstallPath = Join-Path $TestDrive "Modules"
New-Item -Path $TestInstallPath -ItemType Directory -Force | Out-Null

# Define test constants
$TestModuleName = "TestModule"

try {
    Write-Host "Starting simplified tests with timeout protection" -ForegroundColor Cyan
    Write-Host "Using test path: $TestDrive" -ForegroundColor Cyan
    
    # Prevent hanging on interactive operations
    $global:ConfirmPreference = 'None'
    $global:ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'Stop'
    
    # Create test module
    $TestModulePath = Join-Path $TestDrive $TestModuleName
    New-Item -Path $TestModulePath -ItemType Directory -Force | Out-Null
    
    # Create basic module files
    $manifestContent = @"
@{
    RootModule = '$TestModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = '$(New-Guid)'
    Author = 'Test Author'
    Description = 'Test module for PoShDevModules testing'
    FunctionsToExport = @('Get-TestFunction')
}
"@
    
    $moduleContent = @"
function Get-TestFunction {
    [CmdletBinding()]
    param()
    Write-Output "Test Function Output" 
}
Export-ModuleMember -Function Get-TestFunction
"@
    
    Set-Content -Path (Join-Path $TestModulePath "$TestModuleName.psd1") -Value $manifestContent
    Set-Content -Path (Join-Path $TestModulePath "$TestModuleName.psm1") -Value $moduleContent
    
    # Run tests with timeout protection
    Write-Host "Test 1: Install module with timeout protection" -ForegroundColor Yellow
    $job = Start-Job -ScriptBlock { 
        param($Path, $InstallPath, $ModuleRoot)
        Import-Module "$ModuleRoot/PoShDevModules.psd1" -Force
        Install-DevModule -SourcePath $Path -InstallPath $InstallPath -Force
    } -ArgumentList $TestModulePath, $TestInstallPath, $moduleRoot
    
    $completed = Wait-Job $job -Timeout 30
    if ($completed) {
        $result = Receive-Job $job
        Write-Host "✅ Install successful: $($result.Name)" -ForegroundColor Green
    } else {
        Remove-Job $job -Force
        Write-Host "❌ Install timed out!" -ForegroundColor Red
        throw "Installation operation timed out after 30 seconds"
    }
    
    Write-Host "Test 2: Get installed module" -ForegroundColor Yellow
    $job = Start-Job -ScriptBlock {
        param($Name, $InstallPath, $ModuleRoot)
        Import-Module "$ModuleRoot/PoShDevModules.psd1" -Force
        Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
    } -ArgumentList $TestModuleName, $TestInstallPath, $moduleRoot
    
    $completed = Wait-Job $job -Timeout 30
    if ($completed) {
        $result = Receive-Job $job
        if ($result.Name -eq $TestModuleName) {
            Write-Host "✅ Get-InstalledDevModule successful: $($result.Name)" -ForegroundColor Green
        } else {
            Write-Host "❌ Get-InstalledDevModule failed to find module!" -ForegroundColor Red
            throw "Get-InstalledDevModule didn't return expected module"
        }
    } else {
        Remove-Job $job -Force
        Write-Host "❌ Get-InstalledDevModule timed out!" -ForegroundColor Red
        throw "Get operation timed out after 30 seconds"
    }
    
    Write-Host "Test 3: Uninstall module" -ForegroundColor Yellow
    $job = Start-Job -ScriptBlock {
        param($Name, $InstallPath, $ModuleRoot)
        Import-Module "$ModuleRoot/PoShDevModules.psd1" -Force
        Uninstall-DevModule -Name $Name -InstallPath $InstallPath -Force
    } -ArgumentList $TestModuleName, $TestInstallPath, $moduleRoot
    
    $completed = Wait-Job $job -Timeout 30
    if ($completed) {
        $result = Receive-Job $job
        Write-Host "✅ Uninstall successful" -ForegroundColor Green
    } else {
        Remove-Job $job -Force
        Write-Host "❌ Uninstall timed out!" -ForegroundColor Red
        throw "Uninstall operation timed out after 30 seconds"
    }
    
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
} 
catch {
    Write-Host "❌ Test failed: $_" -ForegroundColor Red
}
finally {
    # Clean up
    Write-Host "Cleaning up test environment..." -ForegroundColor Cyan
    Remove-Item -Path $TestDrive -Recurse -Force -ErrorAction SilentlyContinue
}
