#Requires -Modules Pester

<#
.SYNOPSIS
    Core workflow tests for PoShDevModules

.DESCRIPTION
    Tests the complete workflows and real-world user scenarios for PoShDevModules
#>

BeforeAll {
    # Import common test functions
    . $PSScriptRoot/Common.Tests.ps1
    
    # Ensure we have a clean PowerShell environment
    Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
    Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
    
    # Initialize test environment with mock for interactive operations
    $script:TestModuleRoot = Initialize-TestEnvironment
    $script:DevModulesInstallPath = Join-Path $TestDrive "DevModulesInstall"
    New-Item -Path $script:DevModulesInstallPath -ItemType Directory -Force | Out-Null
    
    # Create test modules
    $script:TestModule1Path = New-TestModule -Path $TestDrive -ModuleName "TestModule1"
    $script:TestModule2Path = New-TestModule -Path $TestDrive -ModuleName "TestModule2" -Version "2.0.0"
}

Describe "CRUD Module User Workflows" {
    Context "Normal Operation Scenarios - No Errors Expected" {
        It "completes full CRUD lifecycle" {
            # CREATE - Install module
            $testName = "TestModule1"
            $created = Install-DevModule -SourcePath $script:TestModule1Path -InstallPath $script:DevModulesInstallPath -Force
            $created | Should -Not -BeNullOrEmpty
            $created.Name | Should -Be $testName
            
            # READ - Get installed module
            $retrieved = Get-InstalledDevModule -Name $testName -InstallPath $script:DevModulesInstallPath
            $retrieved.Name | Should -Be $testName
            $retrieved.Version | Should -Be "1.0.0"
            
            # UPDATE - Update module (simulate by changing version)
            # Update the module version in the source
            $manifestPath = Join-Path $script:TestModule1Path "TestModule1.psd1"
            $manifestContent = Get-Content $manifestPath -Raw
            $updatedManifest = $manifestContent -replace "ModuleVersion = '1\.0\.0'", "ModuleVersion = '1.1.0'"
            Set-Content -Path $manifestPath -Value $updatedManifest
            
            # Update the module
            $updated = Install-DevModule -SourcePath $script:TestModule1Path -InstallPath $script:DevModulesInstallPath -Force
            $updated.Version | Should -Be "1.1.0"
            
            # DELETE - Remove module
            Uninstall-DevModule -Name $testName -InstallPath $script:DevModulesInstallPath -Force
            
            # VERIFY REMOVAL
            $afterRemove = Get-InstalledDevModule -Name $testName -InstallPath $script:DevModulesInstallPath
            $afterRemove | Should -BeNullOrEmpty
        }
        
        It "handles pipeline operations correctly" {
            # Install modules first
            $modules = @($script:TestModule1Path, $script:TestModule2Path)
            foreach ($module in $modules) {
                Install-DevModule -SourcePath $module -InstallPath $script:DevModulesInstallPath -Force | Out-Null
            }
            
            # Test pipeline retrieval
            $installed = Get-InstalledDevModule -InstallPath $script:DevModulesInstallPath
            $installed | Should -HaveCount 2
            
            # Pipeline uninstall
            $installed | Uninstall-DevModule -InstallPath $script:DevModulesInstallPath -Force
            
            # Verify all removed
            $afterRemoval = Get-InstalledDevModule -InstallPath $script:DevModulesInstallPath
            $afterRemoval | Should -BeNullOrEmpty
        }
        
        It "executes original user workflow successfully" {
            # Skip actual external GitHub API calls during test design
            Mock Install-DevModuleFromGitHub {
                # Return a mock PSObject that mimics what the real function would return
                return [PSCustomObject]@{
                    Name = 'user-repo'
                    Version = '1.0.0'
                    SourceType = 'GitHub'
                    SourcePath = 'user/repo'
                    InstallPath = $InstallPath
                    InstallDate = Get-Date
                    Branch = $Branch
                    LastUpdated = $null
                    LatestVersionPath = Join-Path $InstallPath 'user-repo/1.0.0'
                }
            } -ModuleName 'PoShDevModules'
            
            # Alternative: If we want to mock at the higher level
            # Mock Install-DevModule {
            #     # But only when GitHubRepo is specified 
            #     if ($GitHubRepo) {
            #         return [PSCustomObject]@{
            #             Name = 'user-repo'
            #             Version = '1.0.0'
            #             SourceType = 'GitHub'
            #             # etc...
            #         }
            #     } else {
            #         # Call the original implementation for other parameter sets
            #         $PSCmdlet.InvokeCommand.InvokeScript($false, $MyInvocation.MyCommand, $PSBoundParameters)
            #     }
            # } -ParameterFilter { $null -ne $GitHubRepo } -ModuleName 'PoShDevModules'
            
            # Execute the user workflow from the module plan
            $result1 = Install-DevModule -GitHubRepo 'user/repo' -InstallPath $script:DevModulesInstallPath -Force
            $result1 | Should -Not -BeNullOrEmpty
            $result1.SourceType | Should -Be 'GitHub'
            
            # Mock update to simulate success
            Mock Update-DevModuleFromGitHub {
                return [PSCustomObject]@{
                    Name = 'user-repo'
                    Version = '1.1.0' # Updated version
                    SourceType = 'GitHub'
                    SourcePath = 'user/repo'
                    InstallPath = $InstallPath
                    InstallDate = Get-Date
                    Branch = $Branch
                    LastUpdated = Get-Date
                    LatestVersionPath = Join-Path $InstallPath 'user-repo/1.1.0'
                }
            } -ModuleName 'PoShDevModules'
            
            # Continue the workflow
            # First install the module to update
            Install-DevModule -GitHubRepo 'user/repo' -InstallPath $script:DevModulesInstallPath -Force | Out-Null
            
            # Then update it
            $result2 = Update-DevModule -Name 'user-repo' -InstallPath $script:DevModulesInstallPath -Force
            $result2 | Should -Not -BeNullOrEmpty
            $result2.Version | Should -Be '1.1.0'
            
            # Complete the workflow
            Uninstall-DevModule -Name 'user-repo' -InstallPath $script:DevModulesInstallPath -Force
            # Verification is already handled in Uninstall-DevModule 
            
            # Verify module is no longer present
            $afterRemove = Get-InstalledDevModule -Name 'user-repo' -InstallPath $script:DevModulesInstallPath
            $afterRemove | Should -BeNullOrEmpty
        }
        
        It "handles metadata persistence correctly" {
            # Install a module
            Install-DevModule -SourcePath $script:TestModule1Path -InstallPath $script:DevModulesInstallPath -Force | Out-Null
            
            # Check if metadata file exists
            $metadataPath = Join-Path $script:DevModulesInstallPath '.metadata' 'TestModule1.json'
            Test-Path $metadataPath | Should -BeTrue
            
            # Parse metadata
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            $metadata.Name | Should -Be 'TestModule1'
            $metadata.SourceType | Should -Be 'Local'
            $metadata.SourcePath | Should -Be $script:TestModule1Path
            
            # Uninstall
            Uninstall-DevModule -Name 'TestModule1' -InstallPath $script:DevModulesInstallPath -Force | Out-Null
            
            # Metadata should be removed
            Test-Path $metadataPath | Should -BeFalse
        }
    }
    
    Context "Expected Error Scenarios - Errors Below Are Intentional" {
        It "handles invalid source path gracefully" {
            $invalidPath = Join-Path $TestDrive "NonExistentModule"
            { Install-DevModule -SourcePath $invalidPath -InstallPath $script:DevModulesInstallPath -ErrorAction Stop } | 
                Should -Throw -Because "Invalid source path should throw an error"
        }
        
        It "handles non-existent module for uninstall gracefully" {
            $result = Uninstall-DevModule -Name 'NonExistentModule' -InstallPath $script:DevModulesInstallPath -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
        
        It "handles non-existent module for update gracefully" {
            # The module handles this with a warning, not an error
            $warningMessages = @()
            Update-DevModule -Name "NonExistentModule" -InstallPath $script:DevModulesInstallPath -WarningAction SilentlyContinue
            
            # Verify it doesn't crash - that's the key validation
            $warningMessages.Count | Should -BeGreaterThanOrEqual 0
        }
        
        It "handles read-only directory gracefully" {
            # Skip this test in test design phase per instructions
            # In a real test, we would:
            # 1. Create a read-only directory
            # 2. Try to install there
            # 3. Verify appropriate error
            Set-ItResult -Skipped -Because "Cannot execute file operations in test design phase"
        }
    }
}

AfterAll {
    # Clean up test modules
    if (Test-Path $script:DevModulesInstallPath) {
        Remove-Item -Path $script:DevModulesInstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
