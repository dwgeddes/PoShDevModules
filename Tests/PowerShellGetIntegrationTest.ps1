# Test PowerShellGet Integration for PoShDevModules
# This tests the new RegisterWithPowerShellGet functionality

param(
    [string]$TestModulePath = "/tmp/TestPowerShellGetModule"
)

$ModulePath = Split-Path $PSScriptRoot -Parent
Import-Module $ModulePath -Force

Write-Host "=== Testing PowerShellGet Integration ===" -ForegroundColor Green

# Clean up any existing test module
if (Test-Path $TestModulePath) {
    Remove-Item -Path $TestModulePath -Recurse -Force
}

# Create a simple test module
Write-Host "`n1. Creating test module..." -ForegroundColor Yellow
New-Item -Path $TestModulePath -ItemType Directory -Force | Out-Null

$manifestContent = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'test-psget-1234'
    Author = 'Test Author'
    Description = 'Test module for PowerShellGet integration'
    FunctionsToExport = @('Test-PowerShellGetFunction')
}
"@
Set-Content -Path (Join-Path $TestModulePath "TestPowerShellGetModule.psd1") -Value $manifestContent

$moduleContent = @"
function Test-PowerShellGetFunction {
    [CmdletBinding()]
    param()
    Write-Output "PowerShellGet integration test function works!"
}

Export-ModuleMember -Function Test-PowerShellGetFunction
"@
Set-Content -Path (Join-Path $TestModulePath "TestPowerShellGetModule.psm1") -Value $moduleContent

Write-Host "   ✓ Test module created at $TestModulePath" -ForegroundColor Green

# Test installation WITHOUT PowerShellGet registration
Write-Host "`n2. Testing normal installation (without PowerShellGet)..." -ForegroundColor Yellow
try {
    $normalInstall = Install-DevModule -SourcePath $TestModulePath -Force -LogLevel Silent
    if ($normalInstall) {
        Write-Host "   ✓ Normal installation successful" -ForegroundColor Green
        
        # Check if it appears in Get-InstalledModule (should NOT appear)
        $inPSGet = Get-InstalledModule -Name "TestPowerShellGetModule" -ErrorAction SilentlyContinue
        if (-not $inPSGet) {
            Write-Host "   ✓ Module correctly NOT in Get-InstalledModule (as expected)" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Module unexpectedly found in Get-InstalledModule" -ForegroundColor Red
        }
        
        # Remove it
        Uninstall-DevModule -Name "TestPowerShellGetModule" -Force -LogLevel Silent
        Write-Host "   ✓ Normal installation test module removed" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠ Normal installation test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test installation WITH PowerShellGet registration
Write-Host "`n3. Testing installation with PowerShellGet registration..." -ForegroundColor Yellow
try {
    $psgetInstall = Install-DevModule -SourcePath $TestModulePath -RegisterWithPowerShellGet -Force -LogLevel Normal
    if ($psgetInstall) {
        Write-Host "   ✓ PowerShellGet installation successful" -ForegroundColor Green
        
        # Check if it appears in Get-InstalledModule (SHOULD appear)
        Start-Sleep 1  # Give it a moment
        $inPSGet = Get-InstalledModule -Name "TestPowerShellGetModule" -ErrorAction SilentlyContinue
        if ($inPSGet) {
            Write-Host "   ✓ Module correctly appears in Get-InstalledModule!" -ForegroundColor Green
            Write-Host "     Name: $($inPSGet.Name), Version: $($inPSGet.Version)" -ForegroundColor Cyan
            Write-Host "     Repository: $($inPSGet.Repository)" -ForegroundColor Cyan
        } else {
            Write-Host "   ✗ Module not found in Get-InstalledModule" -ForegroundColor Red
        }
        
        # Test that it also appears in our own Get-InstalledDevModule
        $inDevModules = Get-InstalledDevModule -Name "TestPowerShellGetModule" -LogLevel Silent
        if ($inDevModules) {
            Write-Host "   ✓ Module also appears in Get-InstalledDevModule" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Module not found in Get-InstalledDevModule" -ForegroundColor Red
        }
        
        # Test removal
        Write-Host "`n4. Testing removal (should clean up PowerShellGet too)..." -ForegroundColor Yellow
        Uninstall-DevModule -Name "TestPowerShellGetModule" -Force -LogLevel Normal
        
        # Verify it's gone from both systems
        Start-Sleep 1
        $inPSGetAfter = Get-InstalledModule -Name "TestPowerShellGetModule" -ErrorAction SilentlyContinue
        $inDevModulesAfter = Get-InstalledDevModule -Name "TestPowerShellGetModule" -LogLevel Silent
        
        if (-not $inPSGetAfter -and -not $inDevModulesAfter) {
            Write-Host "   ✓ Module successfully removed from both systems!" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Module removal may be incomplete:" -ForegroundColor Yellow
            if ($inPSGetAfter) { Write-Host "     Still in Get-InstalledModule" -ForegroundColor Yellow }
            if ($inDevModulesAfter) { Write-Host "     Still in Get-InstalledDevModule" -ForegroundColor Yellow }
        }
    }
} catch {
    Write-Host "   ✗ PowerShellGet installation test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Write-Host "`n5. Cleaning up..." -ForegroundColor Yellow
if (Test-Path $TestModulePath) {
    Remove-Item -Path $TestModulePath -Recurse -Force
    Write-Host "   ✓ Test module directory cleaned up" -ForegroundColor Green
}

Write-Host "`n=== PowerShellGet Integration Test Complete ===" -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor White
Write-Host "- Modules can be installed with optional PowerShellGet registration" -ForegroundColor White
Write-Host "- When registered, they appear in Get-InstalledModule" -ForegroundColor White  
Write-Host "- When removed, they are cleaned up from both systems" -ForegroundColor White
Write-Host "- The -RegisterWithPowerShellGet switch gives you the choice" -ForegroundColor White
