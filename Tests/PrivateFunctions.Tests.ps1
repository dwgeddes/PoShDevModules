#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for private helper functions

.DESCRIPTION
    Tests for internal helper functions used by the PoShDevModules module
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Import private functions for testing (using reflection)
    $privateFunctions = @(
        'Get-GitHubRepoInfo',
        'Save-ModuleMetadata'
    )
    
    foreach ($function in $privateFunctions) {
        # Get the private function and make it available for testing
        $functionDef = Get-Content (Join-Path $PSScriptRoot '..' 'Private' "$function.ps1") -Raw
        . ([ScriptBlock]::Create($functionDef))
    }
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "PrivateFunction_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Get-GitHubRepoInfo" {
    Context "Repository Format Parsing" {
        It "Should parse simple owner/repo format" {
            $result = Get-GitHubRepoInfo -GitHubRepo "microsoft/powershell"
            $result.Owner | Should -Be "microsoft"
            $result.Repo | Should -Be "powershell"
            $result.FullName | Should -Be "microsoft/powershell"
        }
        
        It "Should parse GitHub URL format" {
            $result = Get-GitHubRepoInfo -GitHubRepo "https://github.com/microsoft/powershell"
            $result.Owner | Should -Be "microsoft"
            $result.Repo | Should -Be "powershell"
            $result.FullName | Should -Be "microsoft/powershell"
        }
        
        It "Should parse GitHub URL with .git suffix" {
            $result = Get-GitHubRepoInfo -GitHubRepo "https://github.com/microsoft/powershell.git"
            $result.Owner | Should -Be "microsoft"
            $result.Repo | Should -Be "powershell"
            $result.FullName | Should -Be "microsoft/powershell"
        }
        
        It "Should parse GitHub URL with trailing slash" {
            $result = Get-GitHubRepoInfo -GitHubRepo "https://github.com/microsoft/powershell/"
            $result.Owner | Should -Be "microsoft"
            $result.Repo | Should -Be "powershell"
            $result.FullName | Should -Be "microsoft/powershell"
        }
        
        It "Should handle HTTPS URL" {
            $result = Get-GitHubRepoInfo -GitHubRepo "https://github.com/user/repo"
            $result.Owner | Should -Be "user"
            $result.Repo | Should -Be "repo"
        }
        
        It "Should handle HTTP URL" {
            $result = Get-GitHubRepoInfo -GitHubRepo "http://github.com/user/repo"
            $result.Owner | Should -Be "user"
            $result.Repo | Should -Be "repo"
        }
    }
    
    Context "Error Handling" {
        It "Should throw error for invalid format" {
            { Get-GitHubRepoInfo -GitHubRepo "invalid-format" } | Should -Throw
        }
        
        It "Should throw error for empty string" {
            { Get-GitHubRepoInfo -GitHubRepo "" } | Should -Throw
        }
        
        It "Should throw error for non-GitHub URL" {
            { Get-GitHubRepoInfo -GitHubRepo "https://gitlab.com/user/repo" } | Should -Throw
        }
        
        It "Should throw error for incomplete owner/repo" {
            { Get-GitHubRepoInfo -GitHubRepo "microsoft/" } | Should -Throw
        }
    }
}

Describe "Save-ModuleMetadata" {
    BeforeEach {
        $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall_$(Get-Random)"
        New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
        
        # Create a mock module directory with version-specific structure
        $script:TestModulePath = Join-Path $script:TestInstallPath "TestModule"
        $script:TestModuleVersionPath = Join-Path $script:TestModulePath "2.0.0"
        New-Item -Path $script:TestModuleVersionPath -ItemType Directory -Force | Out-Null
        
        $manifestContent = @"
@{
    ModuleVersion = '2.0.0'
    GUID = 'test1234-5678-9abc-def0-123456789abc'
    Author = 'Test Author'
    Description = 'Test module'
}
"@
        $manifestContent | Set-Content (Join-Path $script:TestModuleVersionPath "TestModule.psd1")
    }
    
    Context "Metadata Creation" {
        It "Should create metadata directory if it doesn't exist" {
            Save-ModuleManifest -ModuleName "TestModule" -SourceType "Local" -SourcePath "/test/path" -InstallPath $script:TestInstallPath
            
            $metadataDir = Join-Path $script:TestInstallPath ".metadata"
            Test-Path $metadataDir | Should -Be $true
        }
        
        It "Should create metadata file with correct content" {
            Save-ModuleManifest -ModuleName "TestModule" -SourceType "Local" -SourcePath "/test/path" -InstallPath $script:TestInstallPath
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "TestModule.json"
            Test-Path $metadataFile | Should -Be $true
            
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            $metadata.Name | Should -Be "TestModule"
            $metadata.SourceType | Should -Be "Local"
            $metadata.SourcePath | Should -Be "/test/path"
            $metadata.Version | Should -Be "2.0.0"
            $metadata.InstallDate | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle GitHub source type with branch and subpath" {
            Save-ModuleManifest -ModuleName "TestModule" -SourceType "GitHub" -SourcePath "user/repo" -InstallPath $script:TestInstallPath -Branch "develop" -ModuleSubPath "src/module"
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "TestModule.json"
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            
            $metadata.SourceType | Should -Be "GitHub"
            $metadata.Branch | Should -Be "develop"
            $metadata.ModuleSubPath | Should -Be "src/module"
        }
        
        It "Should extract version from module manifest" {
            Save-ModuleManifest -ModuleName "TestModule" -SourceType "Local" -SourcePath "/test/path" -InstallPath $script:TestInstallPath
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "TestModule.json"
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            $metadata.Version | Should -Be "2.0.0"
        }
        
        It "Should use directory name when manifest cannot be read" {
            # Remove the manifest file from the version-specific directory
            Remove-Item (Join-Path $script:TestModuleVersionPath "TestModule.psd1") -Force
            
            Save-ModuleManifest -ModuleName "TestModule" -SourceType "Local" -SourcePath "/test/path" -InstallPath $script:TestInstallPath
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "TestModule.json"
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            # Should fall back to using the version directory name
            $metadata.Version | Should -Be "2.0.0"
        }
    }
    
    Context "Error Handling" {
        It "Should not throw error when metadata creation fails" {
            # This test ensures the function handles errors gracefully
            { Save-ModuleManifest -ModuleName "TestModule" -SourceType "Local" -SourcePath "/test/path" -InstallPath "/invalid/path" } | Should -Not -Throw
        }
    }
}
