#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Install-DevModule function

.DESCRIPTION
    Tests for installing modules from local paths and GitHub repositories
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "InstallDevModule_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create test install path
    $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall"
    New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
    
    # Create a mock module for testing local installation
    $script:MockModulePath = Join-Path $script:TestDirectory "TestModule"
    New-Item -Path $script:MockModulePath -ItemType Directory -Force | Out-Null
    
    $mockManifest = @"
@{
    RootModule = 'TestModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Test Author'
    Description = 'Test module for local installation'
    FunctionsToExport = @('Test-LocalFunction')
}
"@
    $mockManifest | Set-Content (Join-Path $script:MockModulePath "TestModule.psd1")
    
    $mockScript = @"
function Test-LocalFunction {
    Write-Output "Local test function called"
}
Export-ModuleMember -Function Test-LocalFunction
"@
    $mockScript | Set-Content (Join-Path $script:MockModulePath "TestModule.psm1")
}

AfterAll {
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Install-DevModule" {
    Context "Parameter Validation" {
        It "Should have mandatory SourcePath parameter in Local parameter set" {
            $command = Get-Command Install-DevModule
            $sourcePathParam = $command.Parameters['SourcePath']
            $sourcePathParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
        
        It "Should validate SourcePath exists" {
            { Install-DevModule -SourcePath "/nonexistent/path" } | Should -Throw
        }
        
        It "Should validate SourcePath exists" {
            { Install-DevModule -SourcePath "/nonexistent/path" } | Should -Throw
        }
    }
    
    Context "Local Installation" {
        It "Should install module from local path" {
            { Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath } | Should -Not -Throw
            
            # With version-specific directories, module will be in TestInstallPath/TestModule/1.0.0/
            $moduleBasePath = Join-Path $script:TestInstallPath "TestModule"
            $versionDirs = Get-ChildItem -Path $moduleBasePath -Directory -ErrorAction SilentlyContinue
            $versionDirs.Count | Should -BeGreaterThan 0
            
            $installedPath = $versionDirs[0].FullName
            Test-Path (Join-Path $installedPath "TestModule.psd1") | Should -Be $true
            Test-Path (Join-Path $installedPath "TestModule.psm1") | Should -Be $true
        }
        
        It "Should create metadata for installed module" {
            Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath -Force
            
            $metadataPath = Join-Path $script:TestInstallPath ".metadata"
            $metadataFile = Join-Path $metadataPath "TestModule.json"
            Test-Path $metadataFile | Should -Be $true
            
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            $metadata.Name | Should -Be "TestModule"
            $metadata.SourceType | Should -Be "Local"
            $metadata.SourcePath | Should -Be $script:MockModulePath
        }
        
        It "Should not overwrite existing module without Force" {
            # First installation
            Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath -Force
            
            # Second installation without Force should fail
            { Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath } | Should -Throw
        }
        
        It "Should overwrite existing module with Force" {
            # First installation
            Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath -Force
            
            # Second installation with Force should succeed
            { Install-DevModule -SourcePath $script:MockModulePath -InstallPath $script:TestInstallPath -Force } | Should -Not -Throw
        }
    }
    
    Context "GitHub Installation" {
        It "Should parse GitHub repository format correctly" {
            # This test doesn't actually download but tests parameter handling
            Mock -ModuleName PoShDevModules Invoke-WebRequest { 
                throw "Network call blocked in test" 
            }
            
            { Install-DevModule -GitHubRepo "user/repo" -InstallPath $script:TestInstallPath } | Should -Throw "*Network call blocked in test*"
        }
        
        It "Should handle different GitHub URL formats" {
            # Test the private Get-GitHubRepoInfo function indirectly
            Mock -ModuleName PoShDevModules Invoke-WebRequest { 
                throw "Network call blocked in test" 
            }
            
            # These should all parse correctly before hitting the network call
            { Install-DevModule -GitHubRepo "microsoft/powershell" -InstallPath $script:TestInstallPath } | Should -Throw "*Network call blocked in test*"
            { Install-DevModule -GitHubRepo "https://github.com/microsoft/powershell" -InstallPath $script:TestInstallPath } | Should -Throw "*Network call blocked in test*"
        }
    }
}
