#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Update-DevModule function

.DESCRIPTION
    Tests for updating installed development modules
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'PoShDevModules.psd1'
    Import-Module $ModulePath -Force
    
    # Create temporary test directory
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "UpdateDevModule_Tests_$(Get-Random)"
    New-Item -Path $script:TestDirectory -ItemType Directory -Force | Out-Null
    
    # Create test install path
    $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall"
    New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
    
    # Create metadata directory
    $script:MetadataPath = Join-Path $script:TestInstallPath ".metadata"
    New-Item -Path $script:MetadataPath -ItemType Directory -Force | Out-Null
    
    # Create a mock installed module
    $script:MockModulePath = Join-Path $script:TestInstallPath "TestModule"
    New-Item -Path $script:MockModulePath -ItemType Directory -Force | Out-Null
    
    $mockManifest = @"
@{
    RootModule = 'TestModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Test Author'
    Description = 'Test module for update testing'
    FunctionsToExport = @('Test-UpdateFunction')
}
"@
    $mockManifest | Set-Content (Join-Path $script:MockModulePath "TestModule.psd1")
    
    $mockScript = @"
function Test-UpdateFunction {
    Write-Output "Update test function called"
}
Export-ModuleMember -Function Test-UpdateFunction
"@
    $mockScript | Set-Content (Join-Path $script:MockModulePath "TestModule.psm1")
    
    # Create metadata for the mock module
    $metadata = @{
        Name = "TestModule"
        Version = "1.0.0"
        SourceType = "Local"
        SourcePath = "/original/source/path"
        InstallDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    $metadata | ConvertTo-Json | Set-Content (Join-Path $script:MetadataPath "TestModule.json")
}

AfterAll {
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Update-DevModule" {
    Context "Parameter Validation" {
        It "Should handle valid module names gracefully when source fails" {
            # This should throw for invalid source path
            { Update-DevModule -Name "TestModule" -InstallPath $script:TestInstallPath -LogLevel Silent -Force } | Should -Throw "*Failed to update module from local source*"
        }
        
        It "Should handle non-existent modules gracefully" {
            # This should write an error but not throw
            $ErrorActionPreference = 'SilentlyContinue'
            $result = Update-DevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath -LogLevel Silent -Force 2>&1
            $ErrorActionPreference = 'Continue'
            $errorRecord = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errorRecord.Exception.Message | Should -Match "is not installed"
        }
    }
    
    Context "Update Process" {
        It "Should find installed modules" {
            $result = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Contain "TestModule"
        }
        
        It "Should handle missing source paths gracefully" {
            # The update should fail with an exception when source path doesn't exist
            { Update-DevModule -Name "TestModule" -InstallPath $script:TestInstallPath -LogLevel Silent -Force } | Should -Throw "*Source path no longer exists*"
        }
    }
    
    Context "All Modules Update" {
        It "Should have mandatory Name parameter" {
            $command = Get-Command Update-DevModule
            $nameParam = $command.Parameters['Name']
            $nameParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
    }
    
    Context "Error Handling" {
        It "Should handle invalid install paths" {
            $ErrorActionPreference = 'SilentlyContinue'
            $result = Update-DevModule -Name "TestModule" -InstallPath "/nonexistent/path" -LogLevel Silent -Force 2>&1
            $ErrorActionPreference = 'Continue'
            $errorRecord = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errorRecord.Exception.Message | Should -Match "is not installed"
        }
        
        It "Should handle corrupted metadata" {
            $corruptedMetadataPath = Join-Path $script:MetadataPath "Corrupted.json"
            "{ invalid json" | Set-Content $corruptedMetadataPath
            
            { Update-DevModule -Name "TestModule" -InstallPath $script:TestInstallPath -LogLevel Silent -Force } | Should -Throw
        }
    }
}
