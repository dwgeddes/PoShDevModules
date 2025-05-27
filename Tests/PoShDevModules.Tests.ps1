#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for PoShDevModules module

.DESCRIPTION
    Comprehensive test suite for the PoShDevModules PowerShell module
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "PoShDevModules_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create a mock module for testing
    $script:MockModulePath = Join-Path $script:TestDirectory "MockModule"
    New-Item -Path $script:MockModulePath -ItemType Directory -Force | Out-Null
    
    # Create mock module manifest
    $mockManifest = @"
@{
    RootModule = 'MockModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Test Author'
    Description = 'Mock module for testing'
    FunctionsToExport = @('Test-MockFunction')
}
"@
    $mockManifest | Set-Content (Join-Path $script:MockModulePath "MockModule.psd1")
    
    # Create mock module script
    $mockScript = @"
function Test-MockFunction {
    Write-Output "Mock function called"
}
Export-ModuleMember -Function Test-MockFunction
"@
    $mockScript | Set-Content (Join-Path $script:MockModulePath "MockModule.psm1")
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove any test modules that might have been installed
    # Import the path helper function
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'Private\Get-DevModulesPath.ps1')
    $testInstallPath = Get-DevModulesPath
    
    if (Test-Path $testInstallPath) {
        $testModules = Get-ChildItem -Path $testInstallPath -Directory -Name -ErrorAction SilentlyContinue | Where-Object { $_ -like "*Test*" -or $_ -like "*Mock*" }
        foreach ($module in $testModules) {
            $modulePath = Join-Path $testInstallPath $module
            Remove-Item -Path $modulePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Also clean up metadata
        $metadataPath = Join-Path $testInstallPath '.metadata'
        if (Test-Path $metadataPath) {
            $testMetadata = Get-ChildItem -Path $metadataPath -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -like "*Test*" -or $_.BaseName -like "*Mock*" }
            foreach ($metadata in $testMetadata) {
                Remove-Item -Path $metadata.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "PoShDevModules Module" {
    Context "Module Import" {
        It "Should import without errors" {
            { Import-Module PoShDevModules -Force } | Should -Not -Throw
        }
        
        It "Should export the expected functions" {
            $commands = Get-Command -Module PoShDevModules
            $expectedFunctions = @('Install-DevModule', 'Get-InstalledDevModule', 'Uninstall-DevModule', 'Update-DevModule', 'Invoke-DevModuleOperation')
            
            foreach ($function in $expectedFunctions) {
                $commands.Name | Should -Contain $function
            }
        }
        
        It "Should have the correct module version" {
            $module = Get-Module PoShDevModules
            $module.Version | Should -Be '1.0.0'
        }
    }
}
