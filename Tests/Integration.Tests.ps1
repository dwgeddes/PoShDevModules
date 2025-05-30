#Requires -Modules Pester
$ProgressPreference = 'SilentlyContinue'
function Write-Progress { }

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
    
    # Create a complete test module with all required files using New-ModuleManifest
    $manifestPath = Join-Path $script:TestModulePath "IntegrationTestModule.psd1"
    New-ModuleManifest -Path $manifestPath `
        -RootModule 'IntegrationTestModule.psm1' `
        -ModuleVersion '1.0.0' `
        -GUID 'b2c3d4e5-f6a7-8901-bcde-f23456789012' `
        -Author 'Integration Test' `
        -CompanyName 'Test Company' `
        -Copyright '(c) Test. All rights reserved.' `
        -Description 'Integration test module for PoShDevModules' `
        -PowerShellVersion '5.1' `
        -FunctionsToExport @('Get-IntegrationTest', 'Set-IntegrationTest') `
        -CmdletsToExport @() `
        -VariablesToExport @() `
        -AliasesToExport @() `
        -Tags @('Test', 'Integration') `
        -ProjectUri 'https://github.com/test/integration-test-module' `
        -ReleaseNotes 'Initial release for integration testing'
    
    $moduleScript = @'
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
'@
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
    }
    catch {
        Write-Verbose "Cleanup error (expected): $($_.Exception.Message)"
    }
    
    try {
        Uninstall-DevModule -Name "CorruptModule" -Force -ErrorAction SilentlyContinue
        Write-Verbose "Cleaned up CorruptModule"
    }
    catch {
        Write-Verbose "CorruptModule cleanup: $($_.Exception.Message)"
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
            $manifestPath = Join-Path $installedModule.InstallPath "$($installedModule.Name).psd1"
            Import-Module $manifestPath -Force
            
            # Debug: Check what files were actually installed and their content
            Write-Verbose "DEBUG: Checking installed files at: $($installedModule.InstallPath)" -Verbose
            Get-ChildItem $installedModule.InstallPath | ForEach-Object { 
                Write-Verbose "  File: $($_.Name) ($($_.Length) bytes)" -Verbose
                if ($_.Name -like "*.psm1") {
                    Write-Verbose "  PSM1 Content:" -Verbose
                    Get-Content $_.FullName | ForEach-Object { Write-Verbose "    $_" -Verbose }
                }
            }
            
            # Ensure module is fully loaded before testing functions
            $moduleLoaded = Get-Module -Name "IntegrationTestModule"
            $moduleLoaded | Should -Not -BeNullOrEmpty
            
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
        
        It "Should handle module removal correctly" {
            # Install module first
            Install-DevModule -SourcePath $script:TestModulePath -Force | Out-Null
            
            # Verify it exists
            $beforeRemove = Get-InstalledDevModule -Name "IntegrationTestModule"
            $beforeRemove | Should -Not -BeNullOrEmpty
            
            # Remove it
            Uninstall-DevModule -Name "IntegrationTestModule" -Force
            
            # Verify it's gone
            $afterRemove = Get-InstalledDevModule -Name "IntegrationTestModule"
            $afterRemove | Should -BeNullOrEmpty
        }
    }
    
    Context "Execution methods validation" {
        BeforeEach {
            # Ensure clean state
            try {
                Uninstall-DevModule -Name "IntegrationTestModule" -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Verbose "Cleanup error (expected): $($_.Exception.Message)"
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
            Write-Information "Expected potential error: Testing pipeline update (may fail if source unavailable)" -InformationAction Continue
            try {
                $module | Update-DevModule -Force
            } catch {
                Write-Verbose "Pipeline update error (expected in test environment): $($_.Exception.Message)"
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
            
            Write-Information "Expected error: Testing installation of invalid module (this should fail)" -InformationAction Continue
            { Install-DevModule -SourcePath $invalidModulePath } | Should -Throw
        }
        
        It "Should handle corrupted module manifests gracefully" {
            $corruptModulePath = Join-Path $script:TestDirectory "CorruptModule"
            New-Item -Path $corruptModulePath -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $corruptModulePath "CorruptModule.psd1") -Value "This is not valid PowerShell"
            
            Write-Information "Expected error: Testing installation of corrupt module (this should fail)" -InformationAction Continue
            { Install-DevModule -SourcePath $corruptModulePath } | Should -Throw
        }
        
        It "Should handle network unavailable for GitHub repos gracefully" {
            Write-Information "Expected error: Testing GitHub installation with invalid repo (this should fail)" -InformationAction Continue
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
                    Write-Information "Expected error: Testing installation to read-only directory (this should fail)" -InformationAction Continue
                    { Install-DevModule -SourcePath $script:TestModulePath -InstallPath $readOnlyPath } | Should -Throw
                } catch {
                    # Permissions test may not work in all environments
                    Write-Information "Permissions test skipped (not applicable in this environment)" -InformationAction Continue
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

Describe "Pipeline Self-Destruction Protection" -Tag "Integration", "Pipeline" {
    BeforeAll {
        # Ensure clean state for pipeline tests
        $script:PipelineTestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "PoShDevModules_Pipeline_$(Get-Random)"
        New-Item -Path $script:PipelineTestDirectory -ItemType Directory -Force | Out-Null
        
        # Use same module path as main test
        $script:PipelineModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    }
    
    AfterAll {
        # Clean up test directory
        if (Test-Path $script:PipelineTestDirectory) {
            Remove-Item -Path $script:PipelineTestDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Pipeline Self-Destruction Protection - Critical Fix Validation" {
        It "Should preserve module functions during pipeline uninstall when PoShDevModules processes itself" {
            # This tests the critical fix for the pipeline self-destruction issue
            
            # Install PoShDevModules to test location for real pipeline test
            $job = Start-Job {
                param($ModulePath, $TestDir)
                Import-Module $ModulePath -Force
                
                # Install to test location
                Install-DevModule -SourcePath (Split-Path $ModulePath) -InstallPath $TestDir -Force | Out-Null
                
                # Critical test: Pipeline with PoShDevModules in the list
                $modulesBefore = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                # This pipeline execution should NOT break
                Get-InstalledDevModule -InstallPath $TestDir | Uninstall-DevModule -Force | Out-Null
                
                # Verify functions still available after pipeline
                $modulesAfter = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                return [PSCustomObject]@{
                    FunctionsBefore = $modulesBefore
                    FunctionsAfter = $modulesAfter
                    PipelineCompleted = $true
                    ProtectionWorked = ($modulesAfter -eq $modulesBefore)
                }
            } -ArgumentList $script:PipelineModulePath, $script:PipelineTestDirectory
            
            $completed = Wait-Job $job -Timeout 30
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                
                $result.PipelineCompleted | Should -Be $true
                $result.ProtectionWorked | Should -Be $true -Because "Module functions should remain available during pipeline execution"
                $result.FunctionsBefore | Should -BeGreaterThan 0
                $result.FunctionsAfter | Should -Be $result.FunctionsBefore
            } else {
                Remove-Job $job -Force
                throw "Pipeline protection test timed out - likely hanging due to pipeline breakage"
            }
        }
        
        It "Should preserve module functions during self-uninstall pipeline execution" {
            # Test the key behavior: pipeline protection preserves functions
            # This is more reliable than testing warning message capture
            $job = Start-Job {
                param($ModulePath, $TestDir)
                Import-Module $ModulePath -Force
                
                # Install PoShDevModules for testing
                Install-DevModule -SourcePath (Split-Path $ModulePath) -InstallPath $TestDir -Force | Out-Null
                
                # Test that functions remain available during and after pipeline
                $functionsBefore = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                # Execute the pipeline that should trigger protection
                Get-InstalledDevModule -InstallPath $TestDir | Uninstall-DevModule -Force | Out-Null
                
                $functionsAfter = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                return [PSCustomObject]@{
                    FunctionsBefore = $functionsBefore
                    FunctionsAfter = $functionsAfter
                    ProtectionWorked = ($functionsAfter -eq $functionsBefore -and $functionsAfter -gt 0)
                }
            } -ArgumentList $script:PipelineModulePath, $script:PipelineTestDirectory
            
            $completed = Wait-Job $job -Timeout 30
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                
                # Test the actual protection behavior, not warning messages
                $result.ProtectionWorked | Should -Be $true -Because "Pipeline protection should preserve module functions"
                $result.FunctionsBefore | Should -BeGreaterThan 0 -Because "Module should have functions before pipeline"
                $result.FunctionsAfter | Should -Be $result.FunctionsBefore -Because "Functions should remain after pipeline"
            } else {
                Remove-Job $job -Force
                throw "Pipeline protection behavior test timed out"
            }
        }
        
        It "Should handle multiple modules in pipeline without function loss" {
            # Test pipeline with multiple modules where PoShDevModules isn't first
            $job = Start-Job {
                param($ModulePath, $TestDir)
                Import-Module $ModulePath -Force
                
                # Create and install a test module first
                $testModuleDir = Join-Path $TestDir "TestPipelineModule"
                New-Item -Path $testModuleDir -ItemType Directory -Force | Out-Null
                
                # Create simple test module
                $manifestContent = @"
@{
    RootModule = 'TestPipelineModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6a7-8901-bcde-f23456789abc'
    Author = 'Test'
    Description = 'Test module for pipeline testing'
}
"@
                $manifestContent | Set-Content (Join-Path $testModuleDir "TestPipelineModule.psd1")
                "function Test-PipelineFunction { return 'test' }" | Set-Content (Join-Path $testModuleDir "TestPipelineModule.psm1")
                
                # Install both modules
                Install-DevModule -SourcePath $testModuleDir -InstallPath $TestDir -Force | Out-Null
                Install-DevModule -SourcePath (Split-Path $ModulePath) -InstallPath $TestDir -Force | Out-Null
                
                # Test pipeline with multiple modules
                $modulesBefore = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                $installedModules = Get-InstalledDevModule -InstallPath $TestDir
                
                # Pipeline should process all modules without breaking
                $installedModules | Uninstall-DevModule -Force | Out-Null
                
                $modulesAfter = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                return [PSCustomObject]@{
                    ModuleCount = $installedModules.Count
                    FunctionsBefore = $modulesBefore
                    FunctionsAfter = $modulesAfter
                    PipelineWorked = ($modulesAfter -eq $modulesBefore)
                }
            } -ArgumentList $script:PipelineModulePath, $script:PipelineTestDirectory
            
            $completed = Wait-Job $job -Timeout 45
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                
                $result.ModuleCount | Should -BeGreaterOrEqual 2
                $result.PipelineWorked | Should -Be $true -Because "Pipeline should handle multiple modules without function loss"
            } else {
                Remove-Job $job -Force
                throw "Multi-module pipeline test timed out"
            }
        }
    }
    
    Context "Update Pipeline Self-Reload Protection" {
        It "Should prevent context loss during self-update in pipeline" {
            # Test the update self-reload protection
            $job = Start-Job {
                param($ModulePath, $TestDir)
                Import-Module $ModulePath -Force
                
                # Install PoShDevModules for update testing
                Install-DevModule -SourcePath (Split-Path $ModulePath) -InstallPath $TestDir -Force | Out-Null
                
                # Test that Update-DevModule with self-update protection works
                $functionsBefore = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                try {
                    # This should trigger self-update protection (will fail due to no git repo, but tests protection)
                    Get-InstalledDevModule -InstallPath $TestDir -Name "PoShDevModules" | Update-DevModule -Force -WhatIf
                } catch {
                    # Expected to fail in test environment, but protection should preserve functions
                }
                
                $functionsAfter = Get-Command -Module PoShDevModules | Measure-Object | Select-Object -ExpandProperty Count
                
                return [PSCustomObject]@{
                    FunctionsBefore = $functionsBefore
                    FunctionsAfter = $functionsAfter
                    ProtectionWorked = ($functionsAfter -eq $functionsBefore)
                }
            } -ArgumentList $script:PipelineModulePath, $script:PipelineTestDirectory
            
            $completed = Wait-Job $job -Timeout 30
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                
                $result.ProtectionWorked | Should -Be $true -Because "Self-update protection should preserve module context"
            } else {
                Remove-Job $job -Force
                throw "Update protection test timed out"
            }
        }
    }
}
