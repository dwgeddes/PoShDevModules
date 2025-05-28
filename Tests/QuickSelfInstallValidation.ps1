#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick validation test for PoShDevModules self-installation

.DESCRIPTION
    A focused test script that validates the core self-installation functionality
    and automatic module discovery in new PowerShell sessions.
#>

Write-Host "PoShDevModules Quick Self-Install Validation" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Errors = @()
}

function Test-Step {
    param([string]$TestName, [scriptblock]$TestCode)
    
    $TestResults.TotalTests++
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    
    try {
        & $TestCode
        $TestResults.PassedTests++
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        return $true
    } catch {
        $TestResults.FailedTests++
        $TestResults.Errors += "$TestName`: $($_.Exception.Message)"
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Get script directory
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ModuleRoot = Split-Path $ScriptDir -Parent
$SelfInstallScript = Join-Path $ModuleRoot 'SelfInstall.ps1'

# Test 1: Self-install with Force
Test-Step "Self-installation with Force parameter" {
    $result = & pwsh -Command "& '$SelfInstallScript' -Force" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SelfInstall.ps1 failed with exit code: $LASTEXITCODE"
    }
}

# Test 2: Module auto-discovery
Test-Step "Module is automatically discoverable" {
    $module = pwsh -c "Get-Module -ListAvailable PoShDevModules"
    if (-not $module) {
        throw "Module not found in PowerShell module path"
    }
    if ($module.Name -ne "PoShDevModules") {
        throw "Module name mismatch: expected 'PoShDevModules', got '$($module.Name)'"
    }
}

# Test 3: Functions work automatically
Test-Step "Functions work without explicit import" {
    $modules = pwsh -c "Get-InstalledDevModule"
    $poShDevModule = $modules | Where-Object { $_.Name -eq "PoShDevModules" }
    if (-not $poShDevModule) {
        throw "PoShDevModules not found in installed modules list"
    }
}

# Test 4: Standard module path location
Test-Step "Module installed in standard PowerShell path" {
    $module = pwsh -c "Get-Module -ListAvailable PoShDevModules"
    $expectedPattern = "\.local/share/powershell/Modules|Documents/PowerShell/Modules"
    if ($module.ModuleBase -notmatch $expectedPattern) {
        throw "Module not in standard path. Found: $($module.ModuleBase)"
    }
}

# Test 5: All required functions available
Test-Step "All required functions are available" {
    $functions = @('Get-InstalledDevModule', 'Install-DevModule', 'Invoke-DevModuleOperation', 'Uninstall-DevModule', 'Update-DevModule')
    foreach ($func in $functions) {
        $command = pwsh -c "Get-Command $func -ErrorAction SilentlyContinue"
        if (-not $command) {
            throw "Function $func is not available"
        }
    }
}

# Results Summary
Write-Host ""
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Total Tests: $($TestResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($TestResults.PassedTests)" -ForegroundColor Green  
Write-Host "Failed: $($TestResults.FailedTests)" -ForegroundColor Red

if ($TestResults.FailedTests -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($errorMessage in $TestResults.Errors) {
        Write-Host "  • $errorMessage" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "OVERALL RESULT: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "OVERALL RESULT: ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "PoShDevModules is properly installed and auto-discoverable!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Test completed at $(Get-Date)" -ForegroundColor Gray
