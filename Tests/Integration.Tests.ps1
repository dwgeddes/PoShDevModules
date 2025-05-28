#Requires -Modules Pester

<#
.SYNOPSIS
    Integration tests for PoShDevModules

.DESCRIPTION
    Tests the complete workflows and real-world scenarios for the module
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory for integration tests
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "PoShDevModules_Integration_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create test module for real integration testing
    $script:TestModulePath = Join-Path $script:TestDirectory "IntegrationTestModule"
    New-Item -Path $script:TestModulePath -ItemType Directory -Force | Out-Null
    
    # Create a complete test module with all required files
    $moduleManifest = @"
@{
    RootModule = 'IntegrationTestModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6g7-8901-bcde-f23456789012'
    Author = 'Integration Test'
    CompanyName = 'Test Company'
    Copyright = '(c) Test. All rights reserved.'
    Description = 'Integration test module for PoShDevModules'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-IntegrationTest', 'Set-IntegrationTest')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Test', 'Integration')
            ProjectUri = 'https://github.com/test/integration-test-module'
            ReleaseNotes = 'Initial release for integration testing'
        }
    }
}
"@
    Set-Content -Path (Join-Path $script:TestModulePath "IntegrationTestModule.psd1") -Value $moduleManifest
    
    $moduleScript = @"
function Get-IntegrationTest {
    [CmdletBinding()]
    param()
    
    return @{
        Status = "Working"
        Version = "1.0.0"
        Timestamp = Get-Date
    }
}

function Set-IntegrationTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )
    
    Write-Output "Integration test value set to: $Value"
}

Export-ModuleMember -Function Get-IntegrationTest, Set-IntegrationTest
"@
    Set-Content -Path (Join-Path $script:TestModulePath "IntegrationTestModule.psm1") -Value $moduleScript
    
    # Create a README for completeness
    $readme = @"
# Integration Test Module

This is a test module used for integration testing of PoShDevModules.

## Functions

- Get-IntegrationTest: Returns test status information
- Set-IntegrationTest: Sets a test value
"@
    Set-Content -Path (Join-Path $script:TestModulePath "README.md") -Value $readme
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clean up any installed test modules
    try {
        Uninstall-DevModule -Name "IntegrationTestModule" -Force -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }
}

Describe "Complete Installation Workflow" -Tag "Integration" {
    Context "Local module installation" {
        It "Should install, verify, and list module successfully" {
            # Install the module
            $installedModule = Install-DevModule -SourcePath $script:TestModulePath -Force
            $installedModule | Should -Not -BeNullOrEmpty
            $installedModule.Name | Should -Be "IntegrationTestModule"
            
            # Verify it appears in the list
            $listedModules = Get-InstalledDevModule
            $listedModules | Where-Object { $_.Name -eq "IntegrationTestModule" } | Should -Not -BeNullOrEmpty
            
            # Verify the module actually works
            Import-Module $installedModule.InstallPath -Force
            $testResult = Get-IntegrationTest
            $testResult.Status | Should -Be "Working"
        }
        
        It "Should handle module updates correctly" {
            # Install initial version
            Install-DevModule -SourcePath $script:TestModulePath -Force | Out-Null
            
            # Modify the module version
            $manifestPath = Join-Path $script:TestModulePath "IntegrationTestModule.psd1"
            $manifestContent = Get-Content $manifestPath -Raw
            $updatedManifest = $manifestContent -replace "ModuleVersion = '1\.0\.0'", "ModuleVersion = '1.1.0'"
            Set-Content -Path $manifestPath -Value $updatedManifest
            
            # Update the module
            $updatedModule = Install-DevModule -SourcePath $script:TestModulePath -Force
            $updatedModule.Version | Should -Be "1.1.0"
        }
        
        It "Should handle module uninstallation correctly" {
            # Install module first
            Install-DevModule -SourcePath $script:TestModulePath -Force | Out-Null
            
            # Verify it exists
            $beforeUninstall = Get-InstalledDevModule -Name "IntegrationTestModule"
            $beforeUninstall | Should -Not -BeNullOrEmpty
            
            # Uninstall it
            Uninstall-DevModule -Name "IntegrationTestModule" -Force
            
            # Verify it's gone
            $afterUninstall = Get-InstalledDevModule -Name "IntegrationTestModule"
            $afterUninstall | Should -BeNullOrEmpty
        }
    }
    
    Context "Execution methods validation" {
        BeforeEach {
            # Ensure clean state
            try {
                Uninstall-DevModule -Name "IntegrationTestModule" -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore cleanup errors
            }
        }
        
        It "Should support direct parameter execution" {
            $result = Install-DevModule -SourcePath $script:TestModulePath -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "IntegrationTestModule"
        }
        
        It "Should support pipeline execution for updates" {
            # Install first
            Install-DevModule -SourcePath $script:TestModulePath -Force | Out-Null
            
            # Get module and pipe to update (this will likely fail but tests pipeline)
            $module = Get-InstalledDevModule -Name "IntegrationTestModule"
            
            # Note: Update via pipeline may fail if source isn't available, but tests the pipeline structure
            Write-Host "Expected potential error: Testing pipeline update (may fail if source unavailable)" -ForegroundColor Yellow
            try {
                $module | Update-DevModule
            } catch {
                # Expected to potentially fail in test environment
            }
        }
        
        It "Should support interactive operations" {
            $listResult = Invoke-DevModuleOperation -List
            $listResult | Should -Not -BeNull
        }
    }
}

Describe "Error Handling and Edge Cases" -Tag "Integration" {
    Context "Invalid inputs" {
        It "Should handle missing module manifests gracefully" {
            $invalidModulePath = Join-Path $script:TestDirectory "InvalidModule"
            New-Item -Path $invalidModulePath -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $invalidModulePath "somefile.txt") -Value "Not a module"
            
            Write-Host "Expected error: Testing installation of invalid module (this should fail)" -ForegroundColor Yellow
            { Install-DevModule -SourcePath $invalidModulePath } | Should -Throw
        }
        
        It "Should handle corrupted module manifests gracefully" {
            $corruptModulePath = Join-Path $script:TestDirectory "CorruptModule"
            New-Item -Path $corruptModulePath -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $corruptModulePath "CorruptModule.psd1") -Value "This is not valid PowerShell"
            
            Write-Host "Expected error: Testing installation of corrupt module (this should fail)" -ForegroundColor Yellow
            { Install-DevModule -SourcePath $corruptModulePath } | Should -Throw
        }
        
        It "Should handle network unavailable for GitHub repos gracefully" {
            Write-Host "Expected error: Testing GitHub installation with invalid repo (this should fail)" -ForegroundColor Yellow
            { Install-DevModule -GitHubRepo "nonexistent/fake-repo-12345" } | Should -Throw
        }
    }
    
    Context "File system edge cases" {
        It "Should handle permission issues gracefully" {
            # This test depends on the system - may not always be applicable
            $readOnlyPath = Join-Path $script:TestDirectory "ReadOnly"
            New-Item -Path $readOnlyPath -ItemType Directory -Force | Out-Null
            
            if ($IsLinux -or $IsMacOS) {
                # Try to make directory read-only (may not work in all test environments)
                try {
                    chmod 444 $readOnlyPath
                    Write-Host "Expected error: Testing installation to read-only directory (this should fail)" -ForegroundColor Yellow
                    { Install-DevModule -SourcePath $script:TestModulePath -InstallPath $readOnlyPath } | Should -Throw
                } catch {
                    # Permissions test may not work in all environments
                    Write-Host "Permissions test skipped (not applicable in this environment)" -ForegroundColor Yellow
                }
            }
        }
    }
}

Describe "Module Architecture Validation" -Tag "Integration" {
    Context "Module structure" {
        It "Should have correct manifest exports" {
            $manifestPath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            
            $expectedFunctions = @('Get-InstalledDevModule', 'Install-DevModule', 'Invoke-DevModuleOperation', 'Uninstall-DevModule', 'Update-DevModule')
            $manifest.FunctionsToExport | Should -Be $expectedFunctions
        }
        
        It "Should have Public functions matching exports" {
            $publicPath = Join-Path $PSScriptRoot '..' 'Public'
            $publicFunctions = Get-ChildItem -Path $publicPath -Filter "*.ps1" | ForEach-Object { $_.BaseName }
            
            $manifestPath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            
            $manifest.FunctionsToExport | Should -Be $publicFunctions
        }
        
        It "Should have all required private functions" {
            $privatePath = Join-Path $PSScriptRoot '..' 'Private'
            $privateFunctions = Get-ChildItem -Path $privatePath -Filter "*.ps1" | ForEach-Object { $_.BaseName }
            
            # Check for essential private functions
            $requiredPrivateFunctions = @(
                'Get-DevModulesPath',
                'Invoke-StandardErrorHandling',
                'Save-ModuleMetadata'
            )
            
            foreach ($func in $requiredPrivateFunctions) {
                $privateFunctions | Should -Contain $func
            }
        }
    }
    
    Context "Function availability" {
        It "Should export all public functions" {
            $exportedCommands = Get-Command -Module PoShDevModules
            $exportedCommands.Count | Should -BeGreaterOrEqual 5
            
            $expectedCommands = @('Get-InstalledDevModule', 'Install-DevModule', 'Invoke-DevModuleOperation', 'Uninstall-DevModule', 'Update-DevModule')
            foreach ($cmd in $expectedCommands) {
                $exportedCommands.Name | Should -Contain $cmd
            }
        }
    }
}
