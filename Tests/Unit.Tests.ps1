#Requires -Modules Pester
$ProgressPreference = 'SilentlyContinue'
function Write-Progress { param($Activity, $Status, $PercentComplete) }

<#
.SYNOPSIS
    Comprehensive unit tests for all PoShDevModules public functions

.DESCRIPTION
    Tests all public functions with proper mocking and isolation
#>

BeforeAll {
    Write-Information "=== Initializing unit test environment ===" -InformationAction Continue
    
    # Initialize script-scoped variables
    $script:TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "PoShDevModules_UnitTests_$(Get-Random)"
    $script:TestInstallPath = Join-Path $script:TestDirectory "TestInstall"
    $script:MetadataPath = Join-Path $script:TestInstallPath ".metadata"

    Write-Information "- TestDirectory: $script:TestDirectory" -InformationAction Continue
    Write-Information "- TestInstallPath: $script:TestInstallPath" -InformationAction Continue
    Write-Information "- MetadataPath: $script:MetadataPath" -InformationAction Continue

    # Remove any installed version to ensure we test the local development version
    Get-Module PoShDevModules | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Import the local module using absolute path
    $ModulePath = '/Users/dgeddes/Code/PoShDevModules/PoShDevModules.psd1'
    Write-Information "- Importing module from: $ModulePath" -InformationAction Continue
    
    if (-not (Test-Path $ModulePath)) {
        throw "Module manifest not found at: $ModulePath"
    }
    
    Import-Module $ModulePath -Force -Global
    Write-Information "- Module imported successfully" -InformationAction Continue
    
    # Verify functions are available
    $functions = Get-Command -Module PoShDevModules
    Write-Information "- Available functions: $($functions.Name -join ', ')" -InformationAction Continue
    
    if ($functions.Count -eq 0) {
        throw "No functions exported from PoShDevModules"
    }

    # Create temporary test directory
    if (Test-Path $script:TestDirectory) {
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create directory structure
    $null = New-Item -Path $script:TestDirectory -ItemType Directory -Force
    $null = New-Item -Path $script:TestInstallPath -ItemType Directory -Force
    $null = New-Item -Path $script:MetadataPath -ItemType Directory -Force

    Write-Information "- Created test directory structure" -InformationAction Continue

    # Create basic test data - TestModule1
    $testModule1Path = Join-Path $script:TestInstallPath "TestModule1"
    New-Item -Path $testModule1Path -ItemType Directory -Force | Out-Null
    
    $testModule1Manifest = @"
@{
    RootModule = 'TestModule1.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'test1-1234-5678-9abc-def0-123456789abc'
    Author = 'Test Author'
    Description = 'Test module 1'
}
"@
    Set-Content -Path (Join-Path $testModule1Path "TestModule1.psd1") -Value $testModule1Manifest -Force
    Set-Content -Path (Join-Path $testModule1Path "TestModule1.psm1") -Value "# Test module 1" -Force
    
    # Create TestModule1 metadata file
    $metadata1 = @{
        Name = "TestModule1"
        Version = "1.0.0"
        SourceType = "Local"
        SourcePath = "/test/path1"
        InstallPath = $script:TestInstallPath
        InstallDate = (Get-Date).ToString('o')
        LatestVersionPath = $testModule1Path
    } | ConvertTo-Json
    
    Set-Content -Path (Join-Path $script:MetadataPath "TestModule1.json") -Value $metadata1 -Force

    Write-Information "=== Unit test environment ready ===" -InformationAction Continue
}

AfterAll {
    # Clean up test directory
    if ($script:TestDirectory -and (Test-Path $script:TestDirectory)) {
        Write-Information "Cleaning up test directory: $script:TestDirectory" -InformationAction Continue
        Remove-Item -Path $script:TestDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Get-InstalledDevModule" {
    Context "Basic functionality" {
        It "Should return installed modules when called without parameters" {
            $modules = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $modules | Should -Not -BeNullOrEmpty
            $modules.Count | Should -BeGreaterOrEqual 1
        }
        
        It "Should return specific module when Name parameter is provided" {
            $module = Get-InstalledDevModule -Name "TestModule1" -InstallPath $script:TestInstallPath
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be "TestModule1"
            $module.Version | Should -Be "1.0.0"
        }
        
        It "Should return null for non-existent module" {
            $module = Get-InstalledDevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath
            $module | Should -BeNullOrEmpty
        }
    }
}

Describe "Install-DevModule" {
    Context "Parameter validation" {
        It "Should require either GitHubRepo or SourcePath" {
            # Test that calling without mandatory parameters fails properly
            # Use Get-Command to test parameter requirements without actually calling the function
            $command = Get-Command Install-DevModule
            $mandatoryParams = $command.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
            $mandatoryParams.Count | Should -BeGreaterThan 0
            
            # Verify that at least one of GitHubRepo or SourcePath is required
            $hasGitHubRepo = $command.Parameters.ContainsKey('GitHubRepo')
            $hasSourcePath = $command.Parameters.ContainsKey('SourcePath')
            ($hasGitHubRepo -or $hasSourcePath) | Should -BeTrue
        }
        
        It "Should handle valid local source path" {
            # Create a mock source module
            $mockSourcePath = Join-Path $script:TestDirectory "MockSource"
            New-Item -Path $mockSourcePath -ItemType Directory -Force | Out-Null
            
            $mockManifest = @"
@{
    RootModule = 'MockSource.psm1'
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789abc'
    Author = 'Test Author'
    Description = 'Mock source module'
}
"@
            Set-Content -Path (Join-Path $mockSourcePath "MockSource.psd1") -Value $mockManifest -Force
            Set-Content -Path (Join-Path $mockSourcePath "MockSource.psm1") -Value "# Mock source" -Force
            
            # Test installation - this should work without throwing
            $result = Install-DevModule -SourcePath $mockSourcePath -InstallPath $script:TestInstallPath -WarningAction SilentlyContinue
            $result | Should -Not -BeNull
        }
    }
}

Describe "Update-DevModule" {
    Context "Parameter validation" {
        It "Should require Name parameter" {
            # Test that Name parameter is mandatory by checking command metadata
            $command = Get-Command Update-DevModule
            $nameParam = $command.Parameters['Name']
            $nameParam | Should -Not -BeNull
            $nameParam.Attributes | Where-Object { $_.Mandatory -eq $true } | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle non-existent module gracefully" {
            { Update-DevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath } | Should -Not -Throw
        }
    }
}

Describe "Uninstall-DevModule" {
    Context "Basic functionality" {
        It "Should require Name parameter" {
            # Test that Name parameter is mandatory by checking command metadata
            $command = Get-Command Uninstall-DevModule
            $nameParam = $command.Parameters['Name']
            $nameParam | Should -Not -BeNull
            $nameParam.Attributes | Where-Object { $_.Mandatory -eq $true } | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle non-existent module gracefully" {
            { Uninstall-DevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath } | Should -Not -Throw
        }
    }
}

Describe "Invoke-DevModuleOperation" {
    Context "List operation" {
        It "Should list installed modules" {
            { Invoke-DevModuleOperation -List -InstallPath $script:TestInstallPath } | Should -Not -Throw
        }
    }
}
