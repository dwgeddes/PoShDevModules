#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive self-installation tests for PoShDevModules

.DESCRIPTION
    Tests the complete self-installation lifecycle including:
    - Initial installation
    - Installation detection and upgrade
    - Uninstallation
    - Reinstallation
    - Interactive and non-interactive modes
    - Quick validation
    - Error handling and edge cases
    
    This consolidates all self-install related test functionality.
#>

BeforeAll {
    # Get paths
    $script:ModuleSourcePath = Split-Path $PSScriptRoot -Parent
    $script:SelfInstallScript = Join-Path $script:ModuleSourcePath 'SelfInstall.ps1'
    
    # Helper function to get installed module info
    function Get-TestInstalledModuleInfo {
        param([string]$ModuleName = "PoShDevModules")
        $null = $ModuleName # Suppress unused parameter warning
        try {
            # Try to find the installed module in the dev modules path
            $installedModulePath = (Get-ChildItem -Path ~/.local/share/powershell/DevModules/PoShDevModules -Recurse -Filter "*.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            if ($installedModulePath) {
                Import-Module $installedModulePath -Force -ErrorAction Stop
                $installedModule = Get-InstalledDevModule -Name $ModuleName -ErrorAction Stop
                return $installedModule
            }
            return $null
        } catch {
            return $null
        }
    }
    
    # Helper function to test if module is properly installed
    function Test-ModuleProperlyInstalled {
        param([string]$ModuleName = "PoShDevModules")
        # Reference parameter to suppress unused parameter warning
        $null = $ModuleName
        try {
            # Check if module is available in the dev modules path
            $installedModulePath = (Get-ChildItem -Path ~/.local/share/powershell/DevModules/PoShDevModules -Recurse -Filter "*.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            if (-not $installedModulePath) {
                return $false
            }
            
            # Try to import the module
            Import-Module $installedModulePath -Force -ErrorAction Stop
            
            # Check if the main functions are available
            $requiredFunctions = @(
                'Get-InstalledDevModule',
                'Install-DevModule', 
                'Invoke-DevModuleOperation',
                'Uninstall-DevModule',
                'Update-DevModule'
            )
            
            foreach ($func in $requiredFunctions) {
                if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                    return $false
                }
            }
            
            return $true
        } catch {
            return $false
        }
    }
}

Describe "SelfInstall.ps1 Prerequisites" {
    It "SelfInstall.ps1 script exists" {
        Test-Path $script:SelfInstallScript | Should -Be $true
    }
    
    It "SelfInstall.ps1 is executable" {
        if ($IsMacOS) {
            $result = (ls -l $script:SelfInstallScript) -match "x"
            $result | Should -Be $true -Because "SelfInstall.ps1 should be executable on macOS"
        } else {
            $acl = Get-Acl $script:SelfInstallScript
            $acl.Access | Where-Object { $_.FileSystemRights -match 'ExecuteFile' } | Should -Not -BeNullOrEmpty -Because "SelfInstall.ps1 should be executable"
        }
    }
    
    It "Required module files exist in source" {
        $requiredFiles = @(
            'PoShDevModules.psd1',
            'PoShDevModules.psm1',
            'Public',
            'Private'
        )
        
        foreach ($file in $requiredFiles) {
            $path = Join-Path $script:ModuleSourcePath $file
            Test-Path $path | Should -Be $true -Because "$file should exist in module source"
        }
    }
}

Describe "SelfInstall.ps1 Forced Installation" {
    It "Installs module successfully with -Force parameter" {
        $result = & pwsh -Command "& '$script:SelfInstallScript' -Force" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "SelfInstall.ps1 should complete successfully"
        $result | Should -Not -BeNullOrEmpty -Because "Installation should produce output"
    }
    
    It "Module is available after installation" {
        Test-ModuleProperlyInstalled | Should -Be $true -Because "Module should be properly installed and functions available"
    }
    
    It "Get-InstalledDevModule returns PoShDevModules" {
        $modules = Get-InstalledDevModule
        $poShDevModule = $modules | Where-Object { $_.Name -eq "PoShDevModules" }
        $poShDevModule | Should -Not -BeNullOrEmpty -Because "PoShDevModules should appear in installed modules list"
        $poShDevModule.Name | Should -Be "PoShDevModules"
    }
    
    It "All required functions are available" {
        $requiredFunctions = @(
            'Get-InstalledDevModule',
            'Install-DevModule', 
            'Invoke-DevModuleOperation',
            'Uninstall-DevModule',
            'Update-DevModule'
        )
        
        foreach ($func in $requiredFunctions) {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be available after installation"
        }
    }
}

Describe "SelfInstall.ps1 Update Detection" {
    It "Detects existing installation and prompts for update" {
        # This test simulates saying 'y' to the update prompt
        $result = & pwsh -Command "echo 'y' | & '$script:SelfInstallScript'" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "SelfInstall.ps1 should handle existing installation update"
        $result | Should -Not -BeNullOrEmpty -Because "Update process should produce output"
    }
    
    It "Module remains functional after update" {
        Test-ModuleProperlyInstalled | Should -Be $true -Because "Module should remain functional after update"
    }
}

Describe "Complete Installation Cycle" {
    BeforeAll {
        # Ensure we start with the module installed
        if (-not (Test-ModuleProperlyInstalled)) {
            & pwsh -Command "& '$script:SelfInstallScript' -Force" | Out-Null
        }
    }
    
    It "Uninstalls module cleanly" {
        # Get module info before uninstall
        $moduleBeforeUninstall = Get-TestInstalledModuleInfo
        $moduleBeforeUninstall | Should -Not -BeNullOrEmpty -Because "Module should be installed before uninstall test"
        
        # Perform uninstall
        { Uninstall-DevModule -Name "PoShDevModules" -Force } | Should -Not -Throw
        
        # Verify uninstallation
        Start-Sleep -Seconds 1
        Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
        
        # Check if module is still available
        $moduleAfterUninstall = Get-Module -Name PoShDevModules -ListAvailable -ErrorAction SilentlyContinue
        $moduleAfterUninstall | Should -BeNullOrEmpty -Because "Module should not be available after uninstall"
        
        # Check if directory was removed
        Test-Path $moduleBeforeUninstall.InstallPath | Should -Be $false -Because "Installation directory should be removed"
    }
    
    It "Reinstalls module successfully after uninstall" {
        $result = & pwsh -Command "& '$script:SelfInstallScript' -Force" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "Reinstallation should succeed"
        $result | Should -Not -BeNullOrEmpty -Because "Reinstallation should produce output"
    }
    
    It "Module functions work after reinstallation" {
        Test-ModuleProperlyInstalled | Should -Be $true -Because "Module should be fully functional after reinstall"
        
        # Test a simple function call
        $modules = Get-InstalledDevModule
        $poShDevModule = $modules | Where-Object { $_.Name -eq "PoShDevModules" }
        $poShDevModule | Should -Not -BeNullOrEmpty -Because "PoShDevModules should be found after reinstall"
    }
}

Describe "SelfInstall.ps1 Error Handling" {
    It "Handles non-interactive mode properly" {
        # This should auto-force in non-interactive mode
        $result = & pwsh -Command "& '$script:SelfInstallScript'" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "Non-interactive mode should work"
        $result | Should -Not -BeNullOrEmpty -Because "Non-interactive mode should produce output"
    }
    
    It "Maintains module functionality after multiple installations" {
        # Run installation multiple times to test robustness
        for ($i = 1; $i -le 3; $i++) {
            $result = & pwsh -Command "& '$script:SelfInstallScript' -Force" 2>&1
            $result | Should -Not -BeNullOrEmpty -Because "Installation should produce output (iteration $i)"
            $LASTEXITCODE | Should -Be 0 -Because "Multiple installations should work (iteration $i)"
        }
        
        Test-ModuleProperlyInstalled | Should -Be $true -Because "Module should remain functional after multiple installations"
    }
}

AfterAll {
    # Clean up - ensure module is properly installed for other tests
    if (-not (Test-ModuleProperlyInstalled)) {
        & pwsh -Command "& '$script:SelfInstallScript' -Force" | Out-Null
    }
}
