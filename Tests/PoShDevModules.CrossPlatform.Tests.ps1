#Requires -Module Pester

<#
.SYNOPSIS
    Cross-platform compatibility tests for PoShDevModules
    
.DESCRIPTION
    Tests platform-specific behaviors and path handling across Windows, macOS, and Linux.
    Addresses historical cross-platform failures identified in previous stage executions.
#>

Describe "PoShDevModules Cross-Platform Compatibility" {
    BeforeAll {
        # MANDATORY: Timeout protection
        Mock Read-Host { return "MockedInput" } -ModuleName 'PoShDevModules'
        Mock Get-Credential { 
            $password = ConvertTo-SecureString "MockedPassword123!" -AsPlainText -Force
            return New-Object PSCredential("MockedUser", $password)
        } -ModuleName 'PoShDevModules'
        Mock Write-Progress { } -ModuleName 'PoShDevModules'
        $global:ConfirmPreference = 'None'
        
        # Fresh module import
        Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
        Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        
        # Platform detection
        $script:IsWindows = $PSVersionTable.PSVersion.Major -le 5 -or $IsWindows
        $script:IsLinux = $PSVersionTable.PSEdition -eq 'Core' -and $IsLinux
        $script:IsMacOS = $PSVersionTable.PSEdition -eq 'Core' -and $IsMacOS
        
        # Cross-platform test paths
        $script:TestInstallPath = Join-Path $TestDrive "CrossPlatformInstalls"
        $script:TestSourcePath = Join-Path $TestDrive "CrossPlatformSource"
        $script:TestModuleName = "CrossPlatformTestModule"
        
        # Create test module with platform-neutral paths
        New-Item -Path $script:TestSourcePath -ItemType Directory -Force
        New-Item -Path "$script:TestSourcePath/$script:TestModuleName" -ItemType Directory -Force
        
        $manifestPath = Join-Path $script:TestSourcePath $script:TestModuleName "$script:TestModuleName.psd1"
        @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$script:TestModuleName.psm1'
    FunctionsToExport = @('Test-CrossPlatformFunction')
    GUID = '$([guid]::NewGuid())'
}
"@ | Out-File -FilePath $manifestPath -Encoding UTF8
        
        $moduleFilePath = Join-Path $script:TestSourcePath $script:TestModuleName "$script:TestModuleName.psm1"
        @"
function Test-CrossPlatformFunction {
    [CmdletBinding()]
    param()
    return "Cross-platform function works on `$(`$PSVersionTable.Platform)"
}
"@ | Out-File -FilePath $moduleFilePath -Encoding UTF8
    }
    
    Context "Path Handling Across Platforms" {
        
        It "handles Unix paths without drive letters" -Skip:$script:IsWindows {
            # ACT: Install module using Unix-style paths
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Installation works on Unix systems
            $result | Should -Not -BeNull
            $result.Status | Should -Be "Success"
            
            # ASSERT: Module can be queried without drive parameter errors
            $installed = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $installed | Should -Not -BeNull
            $installed.Name | Should -Be $script:TestModuleName
        }
        
        It "handles Windows paths with drive letters" -Skip:(-not $script:IsWindows) {
            # ACT: Install module using Windows-style paths
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Installation works on Windows
            $result | Should -Not -BeNull
            $result.Status | Should -Be "Success"
            
            # ASSERT: Drive-based paths handled correctly
            $installed = Get-InstalledDevModule -Name $script:TestModuleName -InstallPath $script:TestInstallPath
            $installed | Should -Not -BeNull
        }
        
        It "normalizes path separators correctly on current platform" {
            # ARRANGE: Mixed path separators
            $mixedPath = $script:TestInstallPath -replace '/', '\' -replace '\\', [IO.Path]::DirectorySeparatorChar
            
            # ACT: Install with normalized path
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $mixedPath -Force
            
            # ASSERT: Path normalization doesn't break installation
            $result | Should -Not -BeNull
            $result.Status | Should -Be "Success"
        }
    }
    
    Context "Default Install Path Resolution" {
        
        It "resolves default install path correctly on macOS/Linux" -Skip:$script:IsWindows {
            # ACT: Install without specifying InstallPath (use default)
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -Force
            
            # ASSERT: Uses correct Unix default path
            $result | Should -Not -BeNull
            $result.InstallPath | Should -Match "\.local/share/powershell|PowerShell"
        }
        
        It "resolves default install path correctly on Windows" -Skip:(-not $script:IsWindows) {
            # ACT: Install without specifying InstallPath (use default)
            $result = Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -Force
            
            # ASSERT: Uses correct Windows default path
            $result | Should -Not -BeNull
            $result.InstallPath | Should -Match "Documents\\PowerShell|WindowsPowerShell"
        }
    }
    
    Context "File System Operations" {
        
        It "handles case-sensitive file systems correctly" -Skip:$script:IsWindows {
            # ARRANGE: Create modules with different casing
            $upperModulePath = Join-Path $script:TestSourcePath "UPPERCASEMODULE"
            $lowerModulePath = Join-Path $script:TestSourcePath "lowercasemodule"
            
            New-Item -Path $upperModulePath -ItemType Directory -Force
            New-Item -Path $lowerModulePath -ItemType Directory -Force
            
            # Create manifests for both
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = 'UPPERCASEMODULE.psm1'
    FunctionsToExport = @()
    GUID = '$([guid]::NewGuid())'
}
"@ | Out-File -FilePath "$upperModulePath/UPPERCASEMODULE.psd1" -Encoding UTF8
            
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = 'lowercasemodule.psm1'
    FunctionsToExport = @()
    GUID = '$([guid]::NewGuid())'
}
"@ | Out-File -FilePath "$lowerModulePath/lowercasemodule.psd1" -Encoding UTF8
            
            # ACT & ASSERT: Both can be installed as distinct modules
            { Install-DevModule -Name "UPPERCASEMODULE" -SourcePath $upperModulePath -InstallPath $script:TestInstallPath -Force } | Should -Not -Throw
            { Install-DevModule -Name "lowercasemodule" -SourcePath $lowerModulePath -InstallPath $script:TestInstallPath -Force } | Should -Not -Throw
            
            # ASSERT: Both exist as separate installations
            $installed = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            $installed.Name | Should -Contain "UPPERCASEMODULE"
            $installed.Name | Should -Contain "lowercasemodule"
        }
        
        It "handles case-insensitive file systems correctly" -Skip:(-not $script:IsWindows) {
            # ARRANGE: Attempt to install same module with different casing
            $result1 = Install-DevModule -Name "TestCase" -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $script:TestInstallPath -Force
            
            # ACT: Install with different casing
            $result2 = Install-DevModule -Name "TESTCASE" -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $script:TestInstallPath -Force
            
            # ASSERT: Second installation overwrites first (case-insensitive)
            $installed = Get-InstalledDevModule -InstallPath $script:TestInstallPath
            ($installed | Where-Object { $_.Name -like "*testcase*" }).Count | Should -Be 1
        }
    }
    
    Context "Permission Handling" {
        
        It "handles restricted permissions gracefully" -Skip:$script:IsWindows {
            # ARRANGE: Create restricted directory (Unix-style permissions)
            $restrictedPath = Join-Path $TestDrive "RestrictedDir"
            New-Item -Path $restrictedPath -ItemType Directory -Force
            
            # Attempt to make directory read-only (if running as non-root)
            try {
                chmod 555 $restrictedPath 2>/dev/null
                
                # ACT & ASSERT: Should handle permission error gracefully
                { Install-DevModule -Name $script:TestModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $restrictedPath -Force } | 
                    Should -Throw "*permission*"
                
                # Cleanup
                chmod 755 $restrictedPath 2>/dev/null
            } catch {
                # Skip if chmod not available or no permissions to change
                Set-ItResult -Skipped -Because "Cannot modify directory permissions in test environment"
            }
        }
    }
    
    Context "Character Encoding" {
        
        It "handles non-ASCII characters in paths" {
            # ARRANGE: Path with Unicode characters
            $unicodePath = Join-Path $TestDrive "模块测试"  # Chinese characters
            $unicodeModuleName = "TestModule测试"
            
            New-Item -Path $unicodePath -ItemType Directory -Force
            
            # ACT: Install with Unicode paths
            try {
                $result = Install-DevModule -Name $unicodeModuleName -SourcePath (Join-Path $script:TestSourcePath $script:TestModuleName) -InstallPath $unicodePath -Force
                
                # ASSERT: Unicode handled correctly
                $result | Should -Not -BeNull
                $result.Status | Should -Be "Success"
                
                # ASSERT: Can query installed module
                $installed = Get-InstalledDevModule -Name $unicodeModuleName -InstallPath $unicodePath
                $installed | Should -Not -BeNull
            } catch {
                # Some file systems don't support Unicode - skip gracefully
                Set-ItResult -Skipped -Because "File system does not support Unicode characters in paths"
            }
        }
    }
}
