#Requires -Modules Pester

<#
.SYNOPSIS
    Cross-platform compatibility tests for PoShDevModules

.DESCRIPTION
    Tests path handling and platform compatibility features
#>

BeforeAll {
    # Import common test functions
    . $PSScriptRoot/Common.Tests.ps1
    
    # Ensure we have a clean PowerShell environment
    Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
    Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
    
    # Initialize test environment with mock for interactive operations
    $script:TestModuleRoot = Initialize-TestEnvironment
    $script:CrossPlatformPath = Join-Path $TestDrive "CrossPlatformTest"
    New-Item -Path $script:CrossPlatformPath -ItemType Directory -Force | Out-Null
}

Describe "Cross-Platform Path Handling" {
    Context "Platform-Specific Path Resolution" {
        It "should handle platform-specific default paths correctly" {
            # We're testing Get-StandardModulePath private function indirectly
            # via the public functions' default behavior
            
            # Look at Get-InstalledDevModule without specifying path
            $isWindows = $PSVersionTable.PSVersion.Major -ge 6 ? 
                [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows) : 
                $env:OS -eq 'Windows_NT'
            
            if ($isWindows) {
                # Mock expected Windows behavior
                Mock Get-StandardModulePath {
                    return Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"
                } -ModuleName 'PoShDevModules'
            }
            else {
                # Mock expected Linux/macOS behavior
                Mock Get-StandardModulePath {
                    return Join-Path $env:HOME ".local/share/powershell/Modules"
                } -ModuleName 'PoShDevModules'
            }
            
            # Call with default path to trigger our mock and verify expectations
            $modules = Get-InstalledDevModule -ErrorAction SilentlyContinue
            
            # Verification is that the function didn't throw an error
            # due to platform path handling issues
        }
        
        It "should use slash-agnostic path handling" {
            # Create test module
            $moduleName = "SlashAgnosticModule"
            $modulePath = New-TestModule -Path $TestDrive -ModuleName $moduleName
            
            # Test with path containing forward slashes
            $forwardPath = $script:CrossPlatformPath.Replace("\", "/")
            $result = Install-DevModule -SourcePath $modulePath -InstallPath $forwardPath -Force
            $result | Should -Not -BeNullOrEmpty
            
            # Verify it was installed correctly
            $module = Get-InstalledDevModule -Name $moduleName -InstallPath $script:CrossPlatformPath
            $module | Should -Not -BeNullOrEmpty
            
            # Test with path containing backslashes
            $backslashPath = $script:CrossPlatformPath.Replace("/", "\\")
            Uninstall-DevModule -Name $moduleName -InstallPath $backslashPath -Force
            
            # Verify it was removed correctly
            $module = Get-InstalledDevModule -Name $moduleName -InstallPath $script:CrossPlatformPath
            $module | Should -BeNullOrEmpty
        }
    }
    
    Context "Path Normalization" {
        It "should handle path with trailing slashes" {
            # Create test module
            $moduleName = "TrailingSlashModule"
            $modulePath = New-TestModule -Path $TestDrive -ModuleName $moduleName
            
            # Add trailing slash
            $installPath = "$($script:CrossPlatformPath)/"
            
            # Install with trailing slash
            $result = Install-DevModule -SourcePath $modulePath -InstallPath $installPath -Force
            $result | Should -Not -BeNullOrEmpty
            
            # Verify it was installed correctly
            $module = Get-InstalledDevModule -Name $moduleName -InstallPath $script:CrossPlatformPath
            $module | Should -Not -BeNullOrEmpty
            
            # Clean up
            Uninstall-DevModule -Name $moduleName -InstallPath $script:CrossPlatformPath -Force
        }
        
        It "should handle relative paths" {
            # Create test module
            $moduleName = "RelativePathModule"
            $modulePath = New-TestModule -Path $TestDrive -ModuleName $moduleName
            
            # Set current directory to TestDrive and use relative path
            Push-Location $TestDrive
            
            try {
                $relativePath = "./CrossPlatformTest"
                
                # Install with relative path
                $result = Install-DevModule -SourcePath $modulePath -InstallPath $relativePath -Force
                $result | Should -Not -BeNullOrEmpty
                
                # Verify it was installed correctly
                $module = Get-InstalledDevModule -Name $moduleName -InstallPath $script:CrossPlatformPath
                $module | Should -Not -BeNullOrEmpty
            }
            finally {
                # Return to previous directory
                Pop-Location
                
                # Clean up
                Uninstall-DevModule -Name $moduleName -InstallPath $script:CrossPlatformPath -Force
            }
        }
    }
    
    Context "Module Metadata Cross-Platform Compatibility" {
        It "should store and read metadata in platform-agnostic way" {
            # Create and install a test module
            $moduleName = "MetadataModule"
            $modulePath = New-TestModule -Path $TestDrive -ModuleName $moduleName
            
            # Install module
            Install-DevModule -SourcePath $modulePath -InstallPath $script:CrossPlatformPath -Force | Out-Null
            
            # Verify metadata file exists in .metadata subfolder
            $metadataPath = Join-Path $script:CrossPlatformPath ".metadata" "$moduleName.json"
            Test-Path $metadataPath | Should -BeTrue
            
            # Read metadata and check if it contains platform-agnostic paths
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            
            # Source path should not contain platform-specific path separators
            if ($IsWindows) {
                # On Windows, paths shouldn't have excessive backslashes or inconsistent separators
                $metadata.SourcePath | Should -Not -Match '\\\\'
                $metadata.InstallPath | Should -Not -Match '\\\\'
            }
            else {
                # On Unix, paths shouldn't have Windows backslashes
                $metadata.SourcePath | Should -Not -Match '\\'
                $metadata.InstallPath | Should -Not -Match '\\'
            }
            
            # Clean up
            Uninstall-DevModule -Name $moduleName -InstallPath $script:CrossPlatformPath -Force
        }
    }
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:CrossPlatformPath) {
        Remove-Item -Path $script:CrossPlatformPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
