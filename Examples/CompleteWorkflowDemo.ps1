# Example Usage Script for PoShDevModules
# This script demonstrates the key functionality of PoShDevModules

#Requires -Version 5.1

param(
    [string]$InstallPath = $null  # Optional custom install path
)

Write-Host "=== PoShDevModules Example Usage ===" -ForegroundColor Green
Write-Host "This script demonstrates key PoShDevModules functionality" -ForegroundColor Yellow

# Import the module
try {
    Import-Module "$PSScriptRoot/../PoShDevModules.psd1" -Force
    Write-Host "✅ PoShDevModules imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import PoShDevModules: $_"
    exit 1
}

# Create a sample module for demonstration
$sampleModulePath = if ($IsWindows) {
    Join-Path $env:TEMP "SampleDevModule"
} else {
    Join-Path "/tmp" "SampleDevModule"
}
Remove-Item $sampleModulePath -Recurse -Force -ErrorAction SilentlyContinue
New-Item $sampleModulePath -ItemType Directory -Force | Out-Null

Write-Host "`n1. Creating sample module for demonstration..." -ForegroundColor Cyan

# Create sample module manifest
$manifestContent = @'
@{
    ModuleVersion = '1.0.0'
    RootModule = 'SampleDevModule.psm1'
    FunctionsToExport = @('Get-SampleData', 'Set-SampleValue')
    GUID = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
    Author = 'Example Developer'
    Description = 'A sample module for demonstrating PoShDevModules functionality'
}
'@
$manifestContent | Out-File "$sampleModulePath/SampleDevModule.psd1" -Encoding UTF8

# Create sample module file
$moduleContent = @'
function Get-SampleData {
    [CmdletBinding()]
    param(
        [string]$Filter = "*"
    )
    
    $sampleData = @(
        @{ Name = "Item1"; Value = 100; Type = "Primary" }
        @{ Name = "Item2"; Value = 200; Type = "Secondary" }
        @{ Name = "Item3"; Value = 150; Type = "Primary" }
    )
    
    return $sampleData | Where-Object { $_.Name -like $Filter }
}

function Set-SampleValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [int]$Value
    )
    
    Write-Information "Setting value for $Name to $Value" -InformationAction Continue
    return @{ Name = $Name; Value = $Value; Timestamp = Get-Date }
}

Export-ModuleMember -Function Get-SampleData, Set-SampleValue
'@
$moduleContent | Out-File "$sampleModulePath/SampleDevModule.psm1" -Encoding UTF8

Write-Host "   Created sample module at: $sampleModulePath" -ForegroundColor Gray

# Demonstrate PoShDevModules functionality
Write-Host "`n2. Installing the sample module..." -ForegroundColor Cyan

$installParams = @{
    Name = 'SampleDevModule'
    SourcePath = $sampleModulePath
    Force = $true
}

if ($InstallPath) {
    $installParams.InstallPath = $InstallPath
    Write-Host "   Using custom install path: $InstallPath" -ForegroundColor Gray
}

try {
    $installResult = Install-DevModule @installParams
    Write-Host "✅ Module installed successfully" -ForegroundColor Green
    Write-Host "   Name: $($installResult.Name)" -ForegroundColor Gray
    Write-Host "   Version: $($installResult.Version)" -ForegroundColor Gray
    Write-Host "   Source: $($installResult.SourceType)" -ForegroundColor Gray
} catch {
    Write-Error "Installation failed: $_"
    exit 1
}

Write-Host "`n3. Listing installed modules..." -ForegroundColor Cyan
try {
    $listParams = @{}
    if ($InstallPath) { $listParams.InstallPath = $InstallPath }
    
    $installedModules = Get-InstalledDevModule @listParams
    Write-Host "✅ Found $($installedModules.Count) installed development module(s)" -ForegroundColor Green
    
    $installedModules | ForEach-Object {
        Write-Host "   - $($_.Name) v$($_.Version) from $($_.SourceType)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Failed to list modules: $_"
}

Write-Host "`n4. Testing the installed module..." -ForegroundColor Cyan
try {
    # Get the installed module info to find the correct path
    $listParams = @{ Name = 'SampleDevModule' }
    if ($InstallPath) { $listParams.InstallPath = $InstallPath }
    
    $installedModule = Get-InstalledDevModule @listParams
    $modulePath = Join-Path $installedModule.LatestVersionPath "SampleDevModule.psd1"
    
    # Import and test the module
    Import-Module $modulePath -Force
    $testData = Get-SampleData
    Write-Host "✅ Module functions work correctly" -ForegroundColor Green
    Write-Host "   Sample data retrieved: $($testData.Count) items" -ForegroundColor Gray
    
    $setValue = Set-SampleValue -Name "TestItem" -Value 999
    Write-Host "   Set-SampleValue returned: $($setValue.Name) = $($setValue.Value)" -ForegroundColor Gray
    
    Remove-Module SampleDevModule -Force
} catch {
    Write-Warning "Module testing failed: $_"
}

Write-Host "`n5. Demonstrating update functionality..." -ForegroundColor Cyan
try {
    # Modify the source module
    $newModuleContent = $moduleContent + @'

function Get-SampleStats {
    [CmdletBinding()]
    param()
    
    return @{
        TotalItems = 3
        LastUpdated = Get-Date
        Version = "1.1.0"
    }
}

Export-ModuleMember -Function Get-SampleData, Set-SampleValue, Get-SampleStats
'@
    $newModuleContent | Out-File "$sampleModulePath/SampleDevModule.psm1" -Encoding UTF8 -Force
    
    # Update the module
    $updateParams = @{ Name = 'SampleDevModule'; Force = $true }
    if ($InstallPath) { $updateParams.InstallPath = $InstallPath }
    
    $updateResult = Update-DevModule @updateParams
    Write-Host "✅ Module updated successfully" -ForegroundColor Green
    Write-Host "   Updated module: $($updateResult.Name)" -ForegroundColor Gray
} catch {
    Write-Warning "Update failed: $_"
}

Write-Host "`n6. Cleaning up..." -ForegroundColor Cyan
try {
    # Uninstall the module
    $uninstallParams = @{ Name = 'SampleDevModule'; Force = $true }
    if ($InstallPath) { $uninstallParams.InstallPath = $InstallPath }
    
    Uninstall-DevModule @uninstallParams
    Write-Host "✅ Module uninstalled successfully" -ForegroundColor Green
    
    # Clean up sample source
    Remove-Item $sampleModulePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Sample files cleaned up" -ForegroundColor Green
} catch {
    Write-Warning "Cleanup failed: $_"
}

Write-Host "`n=== PoShDevModules Example Complete ===" -ForegroundColor Green
Write-Host "All core functionality demonstrated successfully!" -ForegroundColor Yellow
Write-Host "`nFor more examples, see the README.md file or function help:" -ForegroundColor Cyan
Write-Host "   Get-Help Install-DevModule -Examples" -ForegroundColor Gray
Write-Host "   Get-Help Get-InstalledDevModule -Examples" -ForegroundColor Gray
Write-Host "   Get-Help Update-DevModule -Examples" -ForegroundColor Gray
Write-Host "   Get-Help Uninstall-DevModule -Examples" -ForegroundColor Gray
