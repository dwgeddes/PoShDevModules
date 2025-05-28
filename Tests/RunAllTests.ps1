#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete test runner for PoShDevModules

.DESCRIPTION
    Runs all tests for PoShDevModules including:
    - Unit tests (public and private functions)
    - Integration tests (workflow and cross-function)
    - Self-installation tests (complete lifecycle)
    - System tests (PowerShell Gallery, architecture, performance)

.PARAMETER TestType
    Type of tests to run: All, Unit, Integration, SelfInstall, System

.PARAMETER SkipSelfInstall
    Skip the self-installation tests (useful for CI environments)

.PARAMETER Quick
    Run only essential tests

.EXAMPLE
    ./RunAllTests.ps1

.EXAMPLE
    ./RunAllTests.ps1 -TestType Unit

.EXAMPLE
    ./RunAllTests.ps1 -SkipSelfInstall -Quick
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Unit", "Integration", "SelfInstall", "System")]
    [string]$TestType = "All",
    
    [switch]$SkipSelfInstall,
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
$TestsPath = $PSScriptRoot

Write-Information "PoShDevModules Complete Test Suite" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Test Type: $TestType" -InformationAction Continue
Write-Information "Skip Self-Install: $SkipSelfInstall" -InformationAction Continue
Write-Information "Quick Mode: $Quick" -InformationAction Continue
Write-Information "" -InformationAction Continue

$AllTestResults = @{
    TotalSuites = 0
    PassedSuites = 0
    FailedSuites = 0
    Errors = @()
}

function Invoke-TestSuite {
    param(
        [string]$SuiteName,
        [scriptblock]$TestCode
    )
    
    $AllTestResults.TotalSuites++
    Write-Information "" -InformationAction Continue
    Write-Information "Running $SuiteName..." -InformationAction Continue
    Write-Information "------------------------------" -InformationAction Continue
    
    try {
        $result = & $TestCode
        if ($result -eq $false -or $LASTEXITCODE -ne 0) {
            throw "Test suite failed with exit code $LASTEXITCODE"
        }
        $AllTestResults.PassedSuites++
        Write-Information "✓ $SuiteName completed successfully" -InformationAction Continue
        return $true
    } catch {
        $AllTestResults.FailedSuites++
        $AllTestResults.Errors += "$SuiteName`: $($_.Exception.Message)"
        Write-Information "✗ $SuiteName failed: $($_.Exception.Message)" -InformationAction Continue
        return $false
    }
}

# Check for Pester
try {
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    $PesterAvailable = $true
    Write-Information "✓ Pester 5.0+ available" -InformationAction Continue
} catch {
    Write-Warning "Pester 5.0+ not available. Pester-based tests will be skipped."
    $PesterAvailable = $false
}

# Define test suites
$TestSuites = @{
    Unit = @{
        Name = "Unit Tests"
        File = "Unit.Tests.ps1"
        Description = "Tests for all public and private functions"
        RequiresPester = $true
    }
    Integration = @{
        Name = "Integration Tests"
        File = "Integration.Tests.ps1"
        Description = "End-to-end workflow and cross-function tests"
        RequiresPester = $true
    }
    SelfInstall = @{
        Name = "Self-Installation Tests"
        File = "SelfInstall.Tests.ps1"
        Description = "Complete self-installation lifecycle tests"
        RequiresPester = $true
    }
    System = @{
        Name = "System Tests"
        File = "SystemTests.Tests.ps1"
        Description = "PowerShell Gallery, architecture, and performance tests"
        RequiresPester = $true
    }
}

# Function to run Pester test suites
function Invoke-PesterTestSuite {
    param(
        [string]$TestFile,
        [string]$SuiteName
    )
    
    $testPath = Join-Path $TestsPath $TestFile
    if (-not (Test-Path $testPath)) {
        throw "Test file not found: $TestFile"
    }
    
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $testPath
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = if ($Quick) { 'Minimal' } else { 'Normal' }
    
    $result = Invoke-Pester -Configuration $pesterConfig
    if ($result.Failed -gt 0) {
        throw "$SuiteName failed: $($result.Failed) test failures"
    }
    
    return $true
}

# Run test suites based on TestType parameter
if ($TestType -eq "All") {
    $SuitesToRun = $TestSuites.Keys
} else {
    $SuitesToRun = @($TestType)
}

foreach ($SuiteKey in $SuitesToRun) {
    $Suite = $TestSuites[$SuiteKey]
    
    # Skip self-install tests if requested
    if ($SuiteKey -eq "SelfInstall" -and $SkipSelfInstall) {
        Write-Information "Skipping $($Suite.Name) (SkipSelfInstall flag set)" -InformationAction Continue
        continue
    }
    
    # Skip Pester tests if Pester is not available
    if ($Suite.RequiresPester -and -not $PesterAvailable) {
        Write-Information "Skipping $($Suite.Name) (Pester not available)" -InformationAction Continue
        continue
    }
    
    # Run the test suite
    Invoke-TestSuite $Suite.Name {
        if ($Suite.RequiresPester) {
            Invoke-PesterTestSuite -TestFile $Suite.File -SuiteName $Suite.Name
        }
    }
}

# Quick validation if not in quick mode and not skipping self-install
if (-not $Quick -and -not $SkipSelfInstall -and ($TestType -eq "All" -or $TestType -eq "SelfInstall")) {
    Invoke-TestSuite "Quick Self-Install Validation" {
        $quickValidationScript = Join-Path $TestsPath "QuickSelfInstallValidation.ps1"
        if (Test-Path $quickValidationScript) {
            & $quickValidationScript
        } else {
            Write-Information "QuickSelfInstallValidation.ps1 not found - using integrated validation" -InformationAction Continue
            return $true
        }
    }
}

# Final Results Summary
Write-Information "" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Test Results Summary" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Total Test Suites: $($AllTestResults.TotalSuites)" -InformationAction Continue
Write-Information "Passed: $($AllTestResults.PassedSuites)" -InformationAction Continue
Write-Information "Failed: $($AllTestResults.FailedSuites)" -InformationAction Continue

if ($AllTestResults.Errors.Count -gt 0) {
    Write-Information "" -InformationAction Continue
    Write-Information "Errors encountered:" -InformationAction Continue
    foreach ($testError in $AllTestResults.Errors) {
        Write-Information "  - $testError" -InformationAction Continue
    }
}

if ($AllTestResults.FailedSuites -eq 0) {
    Write-Information "" -InformationAction Continue
    Write-Information "All tests passed!" -InformationAction Continue
    exit 0
} else {
    Write-Information "" -InformationAction Continue
    Write-Information "Some tests failed. Check the output above for details." -InformationAction Continue
    exit 1
}

# Ensure BOM encoding for UTF-8
Set-Content -Path $PSCommandPath -Encoding UTF8 -Force