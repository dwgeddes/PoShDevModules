#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-InstalledDevModule function

.DESCRIPTION
    Tests for listing installed development modules
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "GetInstalledDevModule_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create test install path
    $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall"
    New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
    
    # Create metadata directory and sample metadata
    $script:MetadataPath = Join-Path $script:TestInstallPath ".metadata"
    New-Item -Path $script:MetadataPath -ItemType Directory -Force | Out-Null
    
    # Create sample metadata files
    $metadata1 = @{
        Name = "TestModule1"
        Version = "1.0.0"
        SourceType = "Local"
        SourcePath = "/path/to/TestModule1"
        InstallPath = (Join-Path $script:TestInstallPath "TestModule1")
        InstallDate = (Get-Date).ToString('o')
        Branch = $null
        ModuleSubPath = $null
        LastUpdated = $null
    }
    
    $metadata2 = @{
        Name = "TestModule2"
        Version = "2.0.0"
        SourceType = "GitHub"
        SourcePath = "user/TestModule2"
        InstallPath = (Join-Path $script:TestInstallPath "TestModule2")
        InstallDate = (Get-Date).AddDays(-1).ToString('o')
        Branch = "main"
        ModuleSubPath = ""
        LastUpdated = (Get-Date).ToString('o')
    }
    
    $metadata1 | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:MetadataPath "TestModule1.json")
    $metadata2 | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:MetadataPath "TestModule2.json")
    
    # Create actual module directories to make the test more realistic
    New-Item -Path (Join-Path $script:TestInstallPath "TestModule1") -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $script:TestInstallPath "TestModule2") -ItemType Directory -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Get-InstalledDevModule" {
    Context "When no modules are installed" {
        It "Should return nothing when install path doesn't exist" {
            $result = Get-InstalledDevModule -InstallPath "/nonexistent/path"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return nothing when metadata directory doesn't exist" {
            $emptyPath = Join-Path $script:TestDirectory "Empty"
            New-Item -Path $emptyPath -ItemType Directory -Force | Out-Null
            
            $result = Get-InstalledDevModule -InstallPath $emptyPath
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "When modules are installed" {
        It "Should return all installed modules" {
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $result | Should -HaveCount 2
            $result[0].Name | Should -BeIn @("TestModule1", "TestModule2")
            $result[1].Name | Should -BeIn @("TestModule1", "TestModule2")
        }
        
        It "Should return modules sorted by name" {
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $result[0].Name | Should -Be "TestModule1"
            $result[1].Name | Should -Be "TestModule2"
        }
        
        It "Should include all expected properties" {
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $module = $result[0]
            
            $module.Name | Should -Not -BeNullOrEmpty
            $module.Version | Should -Not -BeNullOrEmpty
            $module.SourceType | Should -BeIn @("Local", "GitHub")
            $module.SourcePath | Should -Not -BeNullOrEmpty
            $module.InstallPath | Should -Not -BeNullOrEmpty
            $module.InstallDate | Should -BeOfType [DateTime]
        }
        
        It "Should handle different source types correctly" {
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            
            $localModule = $result | Where-Object { $_.SourceType -eq "Local" }
            $githubModule = $result | Where-Object { $_.SourceType -eq "GitHub" }
            
            $localModule | Should -Not -BeNullOrEmpty
            $githubModule | Should -Not -BeNullOrEmpty
            
            $githubModule.Branch | Should -Be "main"
            $localModule.Branch | Should -BeNullOrEmpty
        }
    }
    
    Context "Filtering by name" {
        It "Should return specific module when name is provided" {
            $result = Get-InstalledDevModule -Name "TestModule1" -InstallPath $script:TestInstallPath
            $result | Should -HaveCount 1
            $result.Name | Should -Be "TestModule1"
        }
        
        It "Should return warning when module name not found" {
            $result = Get-InstalledDevModule -Name "NonexistentModule" -InstallPath $script:TestInstallPath
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Error handling" {
        It "Should handle corrupted metadata gracefully" {
            # Create corrupted metadata file
            $corruptedPath = Join-Path $script:MetadataPath "Corrupted.json"
            "{ invalid json" | Set-Content $corruptedPath
            
            # Should still return the valid modules and warn about the corrupted one
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $result | Should -HaveCount 2  # Should still get the 2 valid modules
        }
    }
}
