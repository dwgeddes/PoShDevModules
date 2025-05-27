#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Uninstall-DevModule function

.DESCRIPTION
    Tests for uninstalling installed development modules
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "RemoveDevModule_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create test install path
    $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall"
    New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
    
    # Function to set up a test module
    function SetupTestModule {
        param([string]$ModuleName)
        
        # Create module directory
        $modulePath = Join-Path $script:TestInstallPath $ModuleName
        New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
        
        # Create module files
        $manifestContent = @"
@{
    RootModule = '$ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Test Author'
    Description = 'Test module for removal testing'
}
"@
        $manifestContent | Set-Content (Join-Path $modulePath "$ModuleName.psd1")
        
        $moduleContent = @"
function Test-$ModuleName {
    Write-Output "$ModuleName function called"
}
Export-ModuleMember -Function Test-$ModuleName
"@
        $moduleContent | Set-Content (Join-Path $modulePath "$ModuleName.psm1")
        
        # Create metadata
        $metadataDir = Join-Path $script:TestInstallPath ".metadata"
        if (-not (Test-Path $metadataDir)) {
            New-Item -Path $metadataDir -ItemType Directory -Force | Out-Null
        }
        
        $metadata = @{
            Name = $ModuleName
            Version = "1.0.0"
            SourceType = "Local"
            SourcePath = "/test/path/$ModuleName"
            InstallPath = $modulePath
            InstallDate = (Get-Date).ToString('o')
            Branch = $null
            ModuleSubPath = $null
            LastUpdated = $null
        }
        
        $metadata | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $metadataDir "$ModuleName.json")
    }
}

AfterAll {
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Uninstall-DevModule" {
    Context "Parameter Validation" {
        It "Should have mandatory Name parameter" {
            $command = Get-Command Uninstall-DevModule
            $nameParam = $command.Parameters['Name']
            $nameParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
    }
    
    Context "Module Removal" {
        BeforeEach {
            SetupTestModule "TestRemovalModule"
        }
        
        It "Should remove module directory" {
            Uninstall-DevModule -Name "TestRemovalModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent
            
            $modulePath = Join-Path $script:TestInstallPath "TestRemovalModule"
            Test-Path $modulePath | Should -Be $false
        }
        
        It "Should remove module metadata" {
            Uninstall-DevModule -Name "TestRemovalModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "TestRemovalModule.json"
            Test-Path $metadataFile | Should -Be $false
        }
        
        It "Should not be listed in installed modules after removal" {
            Uninstall-DevModule -Name "TestRemovalModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent
            
            $installedModules = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $installedModules.Name | Should -Not -Contain "TestRemovalModule"
        }
    }
    
    Context "Error Handling" {
        It "Should write error when module doesn't exist" {
            $ErrorActionPreference = 'SilentlyContinue'
            $result = Uninstall-DevModule -Name "NonexistentModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent 2>&1
            $ErrorActionPreference = 'Continue'
            $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing module directory gracefully" {
            SetupTestModule "MissingDirModule"
            
            # Remove just the directory, leave metadata
            $modulePath = Join-Path $script:TestInstallPath "MissingDirModule"
            Remove-Item -Path $modulePath -Recurse -Force
            
            # Should still succeed and clean up metadata
            { Uninstall-DevModule -Name "MissingDirModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent } | Should -Not -Throw
            
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "MissingDirModule.json"
            Test-Path $metadataFile | Should -Be $false
        }
        
        It "Should handle missing metadata gracefully" {
            SetupTestModule "MissingMetadataModule"
            
            # Remove just the metadata, leave directory
            $metadataFile = Join-Path $script:TestInstallPath ".metadata" "MissingMetadataModule.json"
            Remove-Item -Path $metadataFile -Force
            
            # Should fail since Get-InstalledDevModule won't find it
            $ErrorActionPreference = 'SilentlyContinue'
            $result = Uninstall-DevModule -Name "MissingMetadataModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent 2>&1
            $ErrorActionPreference = 'Continue'
            $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Confirmation Prompts" {
        BeforeEach {
            SetupTestModule "ConfirmationTestModule"
        }
        
        It "Should support WhatIf parameter" {
            Uninstall-DevModule -Name "ConfirmationTestModule" -InstallPath $script:TestInstallPath -WhatIf
            
            # Module should still exist after WhatIf
            $modulePath = Join-Path $script:TestInstallPath "ConfirmationTestModule"
            Test-Path $modulePath | Should -Be $true
        }
        
        It "Should proceed when Force is specified" {
            Uninstall-DevModule -Name "ConfirmationTestModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent
            
            $modulePath = Join-Path $script:TestInstallPath "ConfirmationTestModule"
            Test-Path $modulePath | Should -Be $false
        }
    }
    
    Context "Module Session Cleanup" {
        BeforeEach {
            SetupTestModule "SessionTestModule"
        }
        
        It "Should attempt to remove module from session" {
            # This test verifies the code path exists, actual session cleanup is hard to test
            { Uninstall-DevModule -Name "SessionTestModule" -InstallPath $script:TestInstallPath -Force -LogLevel Silent } | Should -Not -Throw
        }
    }
}
