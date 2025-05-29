#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick validation test for PoShDevModules self-installation

.DESCRIPTION
    A focused test script that validates the core self-installation functionality
    and automatic module discovery in new PowerShell sessions.
#>

Write-Information "PoShDevModules Quick Self-Install Validation" -InformationAction Continue
Write-Information "=============================================" -InformationAction Continue

$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Errors = @()
}

function Test-Step {
    param([string]$TestName, [scriptblock]$TestCode)
    
    $TestResults.TotalTests++
    Write-Information "Testing: $TestName" -InformationAction Continue
    
    try {
        & $TestCode
        $TestResults.PassedTests++
        Write-Information "✓ PASS: $TestName" -InformationAction Continue
        return $true
    } catch {
        $TestResults.FailedTests++
        $TestResults.Errors += "$TestName`: $($_.Exception.Message)"
        Write-Error "✗ FAIL: $TestName"
        Write-Error "  Error: $($_.Exception.Message)"
        return $false
    }
}

# Get script directory
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ModuleRoot = Split-Path $ScriptDir -Parent
$SelfInstallScript = Join-Path $ModuleRoot 'SelfInstall.ps1'

# Test 1: Self-install with Force
Test-Step "Self-installation with Force parameter" {
    & pwsh -Command "& '$SelfInstallScript' -Force" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "SelfInstall.ps1 failed with exit code: $LASTEXITCODE"
    }
}

# Test 2: Module auto-discovery
Test-Step "Module is automatically discoverable" {
    $moduleFound = pwsh -c "if (Get-Module -ListAvailable PoShDevModules) { 'FOUND' } else { 'NOT_FOUND' }"
    if ($moduleFound -ne "FOUND") {
        throw "Module not found in PowerShell module path"
    }
}

# Test 3: Functions work automatically
Test-Step "Functions work without explicit import" {
    # Just test that Get-InstalledDevModule runs without error
    pwsh -c 'Get-InstalledDevModule | Out-Null' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Get-InstalledDevModule command failed"
    }
}

# Test 4: Standard module path location
Test-Step "Module installed in standard PowerShell path" {
    $modulePath = pwsh -c "(Get-Module -ListAvailable PoShDevModules).ModuleBase"
    $expectedPattern = "\.local/share/powershell/Modules|Documents/PowerShell/Modules"
    if ($modulePath -notmatch $expectedPattern) {
        throw "Module not in standard path. Found: $modulePath"
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
Write-Information "" -InformationAction Continue
Write-Information "Test Results Summary" -InformationAction Continue
Write-Information "====================" -InformationAction Continue
Write-Information "Total Tests: $($TestResults.TotalTests)" -InformationAction Continue
Write-Information "Passed: $($TestResults.PassedTests)" -InformationAction Continue
Write-Information "Failed: $($TestResults.FailedTests)" -InformationAction Continue

if ($TestResults.FailedTests -gt 0) {
    Write-Information "" -InformationAction Continue
    Write-Error "Failed Tests:"
    foreach ($errorMessage in $TestResults.Errors) {
        Write-Error "  • $errorMessage"
    }
    Write-Information "" -InformationAction Continue
    Write-Error "OVERALL RESULT: FAILED"
    exit 1
} else {
    Write-Information "" -InformationAction Continue
    Write-Information "OVERALL RESULT: ALL TESTS PASSED" -InformationAction Continue
    Write-Information "PoShDevModules is properly installed and auto-discoverable!" -InformationAction Continue
}

Write-Information "" -InformationAction Continue
Write-Information "Test completed at $(Get-Date)" -InformationAction Continue
