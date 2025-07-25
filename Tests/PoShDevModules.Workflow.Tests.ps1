#Requires -Module Pester

<#
.SYNOPSIS        @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$script:TestModuleName.psm1'
    FunctionsToExport = @('Test-Function')
    GUID = 'f1d0e1c2-3b4a-5c6d-7e8f-9a0b1c2d3e4f'
}
"@ | Out-File -FilePath $manifestPath -Encoding UTF8mary user workflow tests for PoShDevModules
    
.DESCRIPTION
    Tests actual user scenarios end-to-end with minimal mocking.
    Focus: Real workflows users execute, not implementation details.
#>

Describe "PoShDevModules Primary User Workflows" {
    BeforeAll {
        # Fresh module import FIRST
        Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
        Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        
        # MANDATORY: Timeout protection - prevent hanging tests
        Mock Read-Host { return "MockedInput" } -ModuleName 'PoShDevModules'
        Mock Get-Credential { 
            $password = ConvertTo-SecureString "MockedPassword123!" -AsPlainText -Force
            return New-Object PSCredential("MockedUser", $password)
        } -ModuleName 'PoShDevModules'
        Mock Write-Progress { } -ModuleName 'PoShDevModules'
        $global:ConfirmPreference = 'None'
        $global:ErrorActionPreference = 'Stop'
        
        # Test environment setup
        $script:TestWorkspace = Join-Path $TestDrive "DevModulesWorkspace"
        $script:TestInstallPath = Join-Path $script:TestWorkspace "TestInstalls"
        $script:TestSourcePath = Join-Path $script:TestWorkspace "TestSource"
        $script:TestModuleName = "TestDevModule"
        
        # Create test module source
        New-Item -Path $script:TestSourcePath -ItemType Directory -Force
        New-Item -Path "$script:TestSourcePath/$script:TestModuleName" -ItemType Directory -Force
        
        # Create minimal valid module manifest
        $manifestPath = Join-Path $script:TestSourcePath $script:TestModuleName "$script:TestModuleName.psd1"
        @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$script:TestModuleName.psm1'
    FunctionsToExport = @('Test-Function')
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
}
"@ | Out-File -FilePath $manifestPath -Encoding UTF8
        
        # Create minimal module file
        $moduleFilePath = Join-Path $script:TestSourcePath $script:TestModuleName "$script:TestModuleName.psm1"
        @"
function Test-Function {
    [CmdletBinding()]
    param()
    return "Test function works"
}
"@ | Out-File -FilePath $moduleFilePath -Encoding UTF8
        
        # Mock external APIs only - let PowerShell cmdlets work normally
        Mock Invoke-RestMethod { 
            throw "External API calls should be mocked in tests" 
        } -ModuleName 'PoShDevModules'
    }
    
    Context "Complete Install-to-Use Workflow" {
        
        It "installs module from local path and makes it available" {
            # ACT: User installs module from local development path
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Installation completed successfully
            $result | Should -Not -BeNull
            $result.Name | Should -Be $script:TestModuleName
            $result.InstallPath | Should -BeLike "*$script:TestInstallPath*"
            $result.Status | Should -Be "Success"
            
            # ASSERT: Module files actually copied (account for versioned directory structure)
            $installedModule = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $installedManifest = Join-Path $installedModule.LatestVersionPath "$script:TestModuleName.psd1"
            $installedManifest | Should -Exist
            
            # ASSERT: Module can be imported and used
            Import-Module $installedManifest -Force
            Test-Function | Should -Be "Test function works"
            Remove-Module $script:TestModuleName -Force
        }
        
        It "queries installed modules after installation" {
            # ARRANGE: Module already installed from previous test
            
            # ACT: User queries what's installed
            $installed = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            
            # ASSERT: Shows installed module
            $installed | Should -Not -BeNull
            $installed.Name | Should -Contain $script:TestModuleName
            
            # ACT: User queries specific module
            $specific = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $specific | Should -Not -BeNull
            $specific.Name | Should -Be $script:TestModuleName
        }
        
        It "updates module from source when changes made" {
            # ARRANGE: Modify source module
            $moduleFilePath = Join-Path $script:TestSourcePath $script:TestModuleName "$script:TestModuleName.psm1"
            @"
function Test-Function {
    [CmdletBinding()]
    param()
    return "Updated test function works"
}
"@ | Out-File -FilePath $moduleFilePath -Encoding UTF8 -Force
            
            # ACT: User updates installed module
            $result = Update-DevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Update completed successfully
            $result | Should -Not -BeNull
            $result.Name | Should -Be $script:TestModuleName
            $result.Status | Should -Be "Success"
            
            # ASSERT: Updated code is available (use proper versioned path)
            $installedModule = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $installedModulePath = Join-Path $installedModule.LatestVersionPath "$script:TestModuleName.psd1"
            Import-Module $installedModulePath -Force
            Test-Function | Should -Be "Updated test function works"
            Remove-Module $script:TestModuleName -Force
        }
        
        It "uninstalls module completely" {
            # ACT: User removes installed module
            Uninstall-DevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Module no longer listed as installed
            $remaining = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $remaining | Should -BeNull
            
            # ASSERT: Module files actually removed (check base module directory)
            $installedPath = Join-Path $script:TestInstallPath $script:TestModuleName
            $installedPath | Should -Not -Exist
        }
    }
    
    Context "Error Handling Workflows" {
        
        It "handles invalid source paths gracefully" {
            # ACT & ASSERT: Invalid path produces clear error
            { Install-DevModule -Name "NonExistent" -SourcePath "/nonexistent/path" -InstallPath $script:TestInstallPath } | 
                Should -Throw "*path*"
        }
        
        It "handles missing modules in queries gracefully" {
            # ACT: Query non-existent module
            $result = Get-InstalledDevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath
            
            # ASSERT: Returns null, doesn't throw
            $result | Should -BeNull
        }
        
        It "handles uninstall of non-existent module gracefully" {
            # ACT & ASSERT: Should warn but not throw
            { Uninstall-DevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath -Force } | 
                Should -Not -Throw
        }
    }
    
    Context "Parameter Validation Workflows" {
        
        It "validates parameter types and formats" {
            # ASSERT: Invalid GitHub repo format fails validation
            { Install-DevModule -Name "Test" -GitHubRepo "invalid-repo-format" -InstallPath $script:TestInstallPath } | Should -Throw "*format*"
        }
        
        It "validates source path exists for local installations" {
            # ASSERT: Non-existent source path fails validation
            { Install-DevModule -Name "Test" -SourcePath "/nonexistent/path" -InstallPath $script:TestInstallPath } | Should -Throw "*path*"
        }
    }
}

Describe "PoShDevModules GitHub Integration Workflows" {
    BeforeAll {
        # Inherit timeout protection from parent scope
        $script:TestInstallPath = Join-Path $TestDrive "GitHubInstalls"
        
        # Mock GitHub API responses
        Mock Invoke-RestMethod {
            param($Uri, $Headers, $OutFile)
            
            if ($Uri -like "*github.com/*/archive/*") {
                # Simulate ZIP download when -OutFile is specified
                if ($OutFile) {
                    "Mock ZIP content" | Out-File -FilePath $OutFile -Encoding UTF8
                    return $null  # Invoke-RestMethod with -OutFile returns nothing
                } else {
                    # Return mock response object for API calls without -OutFile
                    return @{
                        name = "test-repo"
                        default_branch = "main"
                    }
                }
            } elseif ($Uri -like "*/repos/*") {
                # Simulate repository info API calls
                return @{
                    name = "test-repo"
                    default_branch = "main"
                }
            }
            
            # Default successful response for any other GitHub API calls
            return @{
                StatusCode = 200
                Content = "Success"
            }
        } -ModuleName 'PoShDevModules'
        
        # Mock Invoke-WebRequest for download operations (no PAT scenario)
        Mock Invoke-WebRequest {
            param($Uri, $OutFile)
            
            if ($Uri -like "*github.com/*/archive/*" -and $OutFile) {
                # Create a mock ZIP file for downloads
                "Mock ZIP content" | Out-File -FilePath $OutFile -Encoding UTF8
                return @{
                    StatusCode = 200
                }
            }
            
            # Default response for other web requests
            return @{
                StatusCode = 200
                Content = "Success"
            }
        } -ModuleName 'PoShDevModules'
        
        # Mock ZIP extraction (would normally be handled by Expand-Archive)
        Mock Expand-Archive {
            param($Path, $DestinationPath)
            
            # Create mock extracted content structure that matches GitHub repo structure
            # GitHub creates: <repo-name>-<branch>/<module-files>
            $mockRepoPath = Join-Path $DestinationPath "test-repo-main"
            New-Item -Path $mockRepoPath -ItemType Directory -Force
            
            # Create the manifest and module files directly in the repo directory
            # (not in a subdirectory, since test doesn't specify ModuleSubPath)
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = 'TestGitHubModule.psm1'
    FunctionsToExport = @('Test-GitHubFunction')
    GUID = 'a2b3c4d5-e6f7-8901-2345-6789abcdef01'
}
"@ | Out-File -FilePath "$mockRepoPath/TestGitHubModule.psd1" -Encoding UTF8
            
            @"
function Test-GitHubFunction {
    return "GitHub module works"
}
"@ | Out-File -FilePath "$mockRepoPath/TestGitHubModule.psm1" -Encoding UTF8
        } -ModuleName 'PoShDevModules'
    }
    
    It "installs module from GitHub repository" {
        # ACT: User installs from GitHub
        $result = Install-DevModule -Name "TestGitHubModule" -GitHubRepo "testuser/test-repo" -InstallPath $script:TestInstallPath -Force
        
        # ASSERT: GitHub installation succeeded
        $result | Should -Not -BeNull
        # Handle case where multiple modules might be returned (get the target module)
        $targetModule = if ($result -is [array]) { 
            $result | Where-Object { $_.Name -eq "TestGitHubModule" } | Select-Object -First 1
        } else { 
            $result 
        }
        $targetModule | Should -Not -BeNull
        $targetModule.Name | Should -Be "TestGitHubModule"
        $targetModule.SourceType | Should -Be "GitHub"
        
        # ASSERT: Module available for use
        $installedModule = Get-InstalledDevModule -Name "TestGitHubModule" -InstallPath $script:TestInstallPath
        $installedModule | Should -Not -BeNull
    }
}
