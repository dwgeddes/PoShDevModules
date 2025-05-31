#Requires -Modules Pester

<#
.SYNOPSIS
    Error handling tests for PoShDevModules

.DESCRIPTION
    Tests error handling, parameter validation, and edge cases
#>

BeforeAll {
    # Import common test functions
    . $PSScriptRoot/Common.Tests.ps1
    
    # Ensure we have a clean PowerShell environment
    Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
    Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
    
    # Initialize test environment with mock for interactive operations
    $script:TestModuleRoot = Initialize-TestEnvironment
    $script:TestInstallPath = Join-Path $TestDrive "ErrorHandlingTest"
    New-Item -Path $script:TestInstallPath -ItemType Directory -Force | Out-Null
    
    # Create a valid test module
    $script:ValidModulePath = New-TestModule -Path $TestDrive -ModuleName "ValidModule"
}

Describe "Parameter Validation" {
    Context "Install-DevModule Parameter Validation" {
        It "should require SourcePath if not using GitHubRepo" {
            # Use -Force to prevent any prompts
            { Install-DevModule -InstallPath $script:TestInstallPath -Force -ErrorAction Stop } | Should -Throw
        }
        
        It "should validate SourcePath exists" {
            $invalidPath = Join-Path $TestDrive "NonExistentModule"
            { Install-DevModule -SourcePath $invalidPath -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
        
        It "should require GitHubRepo to be in valid format" {
            # This fails silently by design, adding -ErrorAction Stop forces it to throw
            { Install-DevModule -GitHubRepo "invalid-format" -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
        
        It "should accept valid SourcePath parameter" {
            $result = Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'ValidModule'
        }
    }
    
    Context "Update-DevModule Parameter Validation" {
        BeforeEach {
            # Ensure module is installed for update tests
            Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force | Out-Null
        }
        
        It "should require Name parameter" {
            { Update-DevModule -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
        
        It "should validate module exists" {
            { Update-DevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "Uninstall-DevModule Parameter Validation" {
        BeforeEach {
            # Ensure module is installed for uninstall tests
            Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force | Out-Null
        }
        
        It "should require Name parameter" {
            { Uninstall-DevModule -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
        
        It "should validate properly with valid parameters" {
            $result = Uninstall-DevModule -Name "ValidModule" -InstallPath $script:TestInstallPath -Force
            # The result could be null or not depending on implementation, but it shouldn't throw
        }
    }
    
    Context "Get-InstalledDevModule Parameter Validation" {
        It "should handle empty InstallPath gracefully" {
            $emptyPath = Join-Path $TestDrive "EmptyDir"
            New-Item -Path $emptyPath -ItemType Directory -Force | Out-Null
            
            $result = Get-InstalledDevModule -InstallPath $emptyPath
            $result | Should -BeNullOrEmpty
        }
        
        It "should return specific module when Name parameter is provided" {
            # Install test module first
            Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force | Out-Null
            
            # Test with Name parameter
            $result = Get-InstalledDevModule -Name "ValidModule" -InstallPath $script:TestInstallPath
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "ValidModule"
        }
        
        It "should return null for non-existent module" {
            $result = Get-InstalledDevModule -Name "NonExistentModule" -InstallPath $script:TestInstallPath
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Error Handling" {
    Context "Expected Error Scenarios - Errors Below Are Intentional" {
        It "should handle corrupt module manifest gracefully" {
            # Create corrupt module
            $corruptModulePath = Join-Path $TestDrive "CorruptModule"
            New-Item -Path $corruptModulePath -ItemType Directory -Force | Out-Null
            
            # Create corrupt manifest
            $manifestPath = Join-Path $corruptModulePath "CorruptModule.psd1"
            Set-Content -Path $manifestPath -Value "This is not a valid PowerShell Data File"
            
            # Create module file
            $psm1Path = Join-Path $corruptModulePath "CorruptModule.psm1"
            Set-Content -Path $psm1Path -Value "# Empty module"
            
            # Attempt to install
            { Install-DevModule -SourcePath $corruptModulePath -InstallPath $script:TestInstallPath -Force -ErrorAction Stop } | Should -Throw
        }
        
        It "should handle missing module files gracefully" {
            # Create incomplete module
            $incompleteModulePath = Join-Path $TestDrive "IncompleteModule"
            New-Item -Path $incompleteModulePath -ItemType Directory -Force | Out-Null
            
            # No psd1 or psm1 files
            
            # Attempt to install
            { Install-DevModule -SourcePath $incompleteModulePath -InstallPath $script:TestInstallPath -Force -ErrorAction Stop } | Should -Throw
        }
        
        It "should handle GitHub API errors gracefully" {
            # Mock failure response
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("404 Not Found")
            } -ModuleName 'PoShDevModules'
            
            # Attempt to install from GitHub
            { Install-DevModule -GitHubRepo "invalid/repo" -InstallPath $script:TestInstallPath -ErrorAction Stop } | Should -Throw
        }
        
        It "should handle installation path creation errors" {
            # Mock failure to create directory
            Mock New-Item {
                throw [System.UnauthorizedAccessException]::new("Access denied")
            } -ParameterFilter { $Path -like "*ValidModule*" } -ModuleName 'PoShDevModules'
            
            # Attempt to install
            { Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "ShouldProcess Implementation" {
    It "should respect WhatIf for Install-DevModule" {
        # Perform operation with -WhatIf
        Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -WhatIf
        
        # Verify module was not actually installed
        $module = Get-InstalledDevModule -Name "ValidModule" -InstallPath $script:TestInstallPath
        $module | Should -BeNullOrEmpty
    }
    
    It "should respect WhatIf for Uninstall-DevModule" {
        # First install the module normally
        Install-DevModule -SourcePath $script:ValidModulePath -InstallPath $script:TestInstallPath -Force
        
        # Perform uninstall with -WhatIf
        Uninstall-DevModule -Name "ValidModule" -InstallPath $script:TestInstallPath -WhatIf
        
        # Verify module is still installed
        $module = Get-InstalledDevModule -Name "ValidModule" -InstallPath $script:TestInstallPath
        $module | Should -Not -BeNullOrEmpty
    }
}

AfterAll {
    # Clean up test modules
    if (Test-Path $script:TestInstallPath) {
        Remove-Item -Path $script:TestInstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
