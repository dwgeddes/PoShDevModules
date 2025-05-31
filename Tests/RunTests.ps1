<#
.SYNOPSIS
    Run all tests for PoShDevModules with timeout protection

.DESCRIPTION
    This script runs all tests for the PoShDevModules module with proper timeout
    protection to prevent hanging operations. It validates the tests pass
    in a fresh PowerShell session.

.EXAMPLE
    ./RunTests.ps1
    
.EXAMPLE
    ./RunTests.ps1 -Tags Integration
#>
param (
    [Parameter()]
    [string[]]$Tags,
    
    [Parameter()]
    [string[]]$ExcludeTags,
    
    [Parameter()]
    [switch]$DontCleanup,
    
    [Parameter()]
    [int]$TimeoutSeconds = 300
)

# Always use strict mode for test running
Set-StrictMode -Version Latest

# Import Pester if needed
$null = Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

# Define test files in order of importance (core functionality first)
$testFiles = @(
    "Workflow.Tests.ps1",     # Core CRUD workflows
    "Protection.Tests.ps1",   # Pipeline self-destruction protection
    "ErrorHandling.Tests.ps1", # Error handling and parameter validation
    "CrossPlatform.Tests.ps1" # Cross-platform path handling
)

# Normalize paths
$moduleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$testsPath = Join-Path $moduleRoot "Tests"

# Default configuration
$configuration = [PesterConfiguration]::Default
$configuration.Run.Path = $testsPath
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $moduleRoot "Logs/TestResults.xml"
$configuration.Run.PassThru = $true
$configuration.Filter.Tag = $Tags
$configuration.Filter.ExcludeTag = $ExcludeTags

# First, ensure tests work individually for better error isolation
$failedTests = @()
$testResults = @{}

Write-Host "Running PoShDevModules Tests with timeout protection..." -ForegroundColor Cyan
Write-Host "Test files: $($testFiles -join ', ')" -ForegroundColor Cyan
Write-Host "Timeout: ${TimeoutSeconds}s" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

foreach ($file in $testFiles) {
    $testFilePath = Join-Path $testsPath $file
    if (-not (Test-Path $testFilePath)) {
        Write-Warning "Test file not found: $testFilePath"
        continue
    }
    
    Write-Host "Testing $file with ${TimeoutSeconds}s timeout..." -ForegroundColor Yellow
    
    # Run the test file with timeout protection
    $job = Start-Job -ScriptBlock {
        param($FilePath, $ModuleRoot)
        
        # Create a fresh session isolated from the current one
        $null = Import-Module Pester -MinimumVersion 5.0
        
        # Ensure we prevent any interactive prompts
        $global:ConfirmPreference = 'None'
        $global:ProgressPreference = 'SilentlyContinue'
        
        # Set configuration
        $config = [PesterConfiguration]::Default
        $config.Run.Path = $FilePath
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'
        
        # Remove and import module to ensure fresh state
        Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $ModuleRoot "PoShDevModules.psd1") -Force
        
        # Mock Read-Host to prevent prompts
        Mock Read-Host { return "MockedInput" }
        
        try {
            # Run the tests
            $testResults = Invoke-Pester -Configuration $config
            return $testResults
        }
        catch {
            Write-Host "Error running tests: $_" -ForegroundColor Red
            return @{
                FailedCount = 1
                PassedCount = 0
                TotalCount = 1
                Duration = [TimeSpan]::FromSeconds(0)
                Error = $_
            }
        }
    } -ArgumentList $testFilePath, $moduleRoot
    
    # Wait for completion with timeout
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    
    if ($completed) {
        $result = Receive-Job -Job $job
        
        # Add error handling in case the result is not a proper Pester result object
        $passedCount = 0
        $failedCount = 0
        $totalCount = 0
        $duration = 0
        
        if ($result -is [PSObject] -and (Get-Member -InputObject $result -Name 'PassedCount' -ErrorAction SilentlyContinue)) {
            $passedCount = $result.PassedCount
            $failedCount = $result.FailedCount
            $totalCount = $result.TotalCount
            
            if (Get-Member -InputObject $result -Name 'Duration' -ErrorAction SilentlyContinue) {
                $duration = $result.Duration.TotalSeconds
            }
        }
        elseif ($result -is [string]) {
            Write-Host "Test returned string output: $result" -ForegroundColor Yellow
            $failedCount = 1  # Consider it a failure
        }
        elseif ($null -eq $result) {
            Write-Host "Test returned null result" -ForegroundColor Yellow
            $failedCount = 1  # Consider it a failure
        }
        else {
            Write-Host "Unexpected test result type: $($result.GetType().FullName)" -ForegroundColor Yellow
            $failedCount = 1  # Consider it a failure
        }
        
        if ($failedCount -gt 0) {
            Write-Host "❌ FAILED: $file ($passedCount passed, $failedCount failed)" -ForegroundColor Red
            $failedTests += $file
            
            # Show failures - simplified to avoid property access issues
            Write-Host "   ❌ Failed tests: $failedCount" -ForegroundColor Red
        }
        else {
            Write-Host "✅ PASSED: $file ($passedCount passed in $([math]::Round($duration, 2))s)" -ForegroundColor Green
        }
        
        # Store results safely
        $testResults[$file] = @{
            Passed = $passedCount
            Failed = $failedCount
            Total = $totalCount
            Duration = $duration
        }
    }
    else {
        # Handle timeout
        Write-Host "⚠️ TIMEOUT: $file test exceeded ${TimeoutSeconds}s timeout!" -ForegroundColor Red
        $failedTests += $file
        Stop-Job -Job $job | Out-Null
        
        $testResults[$file] = @{
            Passed = 0
            Failed = "TIMEOUT"
            Total = "UNKNOWN"
            Duration = $TimeoutSeconds
        }
    }
    
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}

# Report results
Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "Test Results Summary:" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$totalPassed = 0
$totalFailed = 0
$totalDuration = 0

foreach ($file in $testFiles) {
    if ($testResults.ContainsKey($file)) {
        $result = $testResults[$file]
        
        if ($result.Failed -eq "TIMEOUT") {
            Write-Host "$file : ⚠️ TIMEOUT ($($result.Duration)s)" -ForegroundColor Red
        }
        elseif ($result.Failed -gt 0) {
            Write-Host "$file : ❌ FAILED ($($result.Passed) passed, $($result.Failed) failed, $($result.Duration)s)" -ForegroundColor Red
            $totalPassed += $result.Passed
            $totalFailed += $result.Failed
            $totalDuration += $result.Duration
        }
        else {
            Write-Host "$file : ✅ PASSED ($($result.Passed) tests, $($result.Duration)s)" -ForegroundColor Green
            $totalPassed += $result.Passed
            $totalDuration += $result.Duration
        }
    }
    else {
        Write-Host "$file : ⚠️ NOT RUN" -ForegroundColor Yellow
    }
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Total tests passed: $totalPassed" -ForegroundColor $(if ($totalPassed -gt 0) { "Green" } else { "White" })
Write-Host "Total tests failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
Write-Host "Total duration: $([math]::Round($totalDuration, 2))s" -ForegroundColor Cyan

if ($failedTests.Count -eq 0) {
    Write-Host "`n✅ ALL TESTS PASSED! ✅" -ForegroundColor Green
}
else {
    Write-Host "`n❌ SOME TESTS FAILED! ($($failedTests.Count) of $($testFiles.Count) files)" -ForegroundColor Red
    Write-Host "Failed files: $($failedTests -join ', ')" -ForegroundColor Red
    exit 1
}
