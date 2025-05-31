# Run a single test file directly
param (
    [Parameter(Mandatory)]
    [string]$TestFile = "Workflow.Tests.ps1"
)

$ErrorActionPreference = 'Continue'

Write-Host "Running individual test file: $TestFile" -ForegroundColor Cyan

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

# Get file path
$moduleRoot = Split-Path -Parent $PSScriptRoot
$testFilePath = Join-Path $PSScriptRoot $TestFile

if (-not (Test-Path $testFilePath)) {
    Write-Error "Test file not found: $testFilePath"
    return
}

Write-Host "Test file path: $testFilePath" -ForegroundColor Cyan
Write-Host "Module root: $moduleRoot" -ForegroundColor Cyan

# Ensure no existing module
Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue

# Import the module
Import-Module $moduleRoot -Force

# Mock common interactive commands
Mock Read-Host { return "y" }
$global:ConfirmPreference = 'None'

# Set up Pester configuration
$config = [PesterConfiguration]::Default
$config.Run.Path = $testFilePath
$config.Output.Verbosity = 'Detailed'
$config.Run.PassThru = $true

# Run the tests directly
$results = Invoke-Pester -Configuration $config

# Display results
if ($results.FailedCount -gt 0) {
    Write-Host "Tests failed: $($results.FailedCount)" -ForegroundColor Red
    
    # Show each failed test
    foreach ($test in $results.Failed) {
        Write-Host "  ❌ $($test.Name): $($test.ErrorRecord.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "All tests passed: $($results.PassedCount)" -ForegroundColor Green
}

return $results
