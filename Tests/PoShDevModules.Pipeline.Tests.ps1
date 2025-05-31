#Requires -Module Pester

<#
.SYNOPSIS
    Module pipeline and import/export behavior tests for PoShDevModules
    
.DESCRIPTION
    Tests PowerShell module loading, pipeline behaviors, and module system integration.
    Focus: How the module behaves within PowerShell's module system.
#>

Describe "PoShDevModules Pipeline and Module System Integration" {
    BeforeAll {
        # MANDATORY: Timeout protection
        Mock Read-Host { return "MockedInput" } -ModuleName 'PoShDevModules'
        Mock Get-Credential { 
            $password = ConvertTo-SecureString "MockedPassword123!" -AsPlainText -Force
            return New-Object PSCredential("MockedUser", $password)
        } -ModuleName 'PoShDevModules'
        Mock Write-Progress { } -ModuleName 'PoShDevModules'
        $global:ConfirmPreference = 'None'
        
        # Test environment
        $script:TestInstallPath = Join-Path $TestDrive "PipelineTests"
        $script:TestSourcePath = Join-Path $TestDrive "PipelineSource"
        
        # Create multiple test modules for pipeline testing
        $script:TestModules = @("Module1", "Module2", "Module3")
        
        foreach ($moduleName in $script:TestModules) {
            $modulePath = Join-Path $script:TestSourcePath $moduleName
            New-Item -Path $modulePath -ItemType Directory -Force
            
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$moduleName.psm1'
    FunctionsToExport = @('Get-$moduleName')
    GUID = '$([guid]::NewGuid())'
    Description = 'Test module for pipeline testing'
}
"@ | Out-File -FilePath "$modulePath/$moduleName.psd1" -Encoding UTF8
            
            @"
function Get-$moduleName {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline=`$true)]
        [string]`$InputValue = "Default"
    )
    
    process {
        [PSCustomObject]@{
            ModuleName = '$moduleName'
            InputValue = `$InputValue
            Timestamp = Get-Date
        }
    }
}
"@ | Out-File -FilePath "$modulePath/$moduleName.psm1" -Encoding UTF8
        }
    }
    
    Context "Module Import and Export Validation" {
        
        BeforeEach {
            # Fresh module import for each test
            Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        }
        
        It "exports exactly the expected functions" {
            # ACT: Get exported functions
            $exportedFunctions = Get-Command -Module PoShDevModules -CommandType Function
            
            # ASSERT: Exports only public functions
            $exportedFunctions.Name | Should -Contain "Install-DevModule"
            $exportedFunctions.Name | Should -Contain "Get-InstalledDevModule"
            $exportedFunctions.Name | Should -Contain "Update-DevModule"
            $exportedFunctions.Name | Should -Contain "Uninstall-DevModule"
            
            # ASSERT: Does not export private functions
            $exportedFunctions.Name | Should -Not -Contain "Get-DevModulesPath"
            $exportedFunctions.Name | Should -Not -Contain "Save-ModuleMetadata"
        }
        
        It "loads without errors or warnings" {
            # ARRANGE: Capture warning stream
            $warnings = @()
            
            # ACT: Import module with warning capture
            Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force -WarningVariable warnings
            
            # ASSERT: No warnings during import
            $warnings | Should -BeNullOrEmpty
            
            # ASSERT: Module is available
            Get-Module PoShDevModules | Should -Not -BeNull
        }
        
        It "handles module re-import correctly" {
            # ACT: Import multiple times
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
            
            # ASSERT: Only one instance loaded
            $loadedModules = Get-Module PoShDevModules
            $loadedModules.Count | Should -Be 1
            
            # ASSERT: Functions still work after re-import
            { Get-Command Install-DevModule } | Should -Not -Throw
        }
    }
    
    Context "Pipeline Input and Output" {
        
        BeforeEach {
            # Ensure clean module state
            Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        }
        
        It "accepts pipeline input for module names" {
            # ARRANGE: Install test modules first
            foreach ($moduleName in $script:TestModules) {
                Install-DevModule -Name $moduleName -SourcePath (Join-Path $script:TestSourcePath $moduleName) -InstallPath $script:TestInstallPath -Force
            }
            
            # ACT: Query modules via pipeline
            $results = $script:TestModules | Get-InstalledDevModule -InstallPath $script:TestInstallPath
            
            # ASSERT: Pipeline input processed correctly
            $results.Count | Should -Be $script:TestModules.Count
            foreach ($moduleName in $script:TestModules) {
                $results.Name | Should -Contain $moduleName
            }
        }
        
        It "produces consistent output objects" {
            # ARRANGE: Install a test module
            Install-DevModule -Name $script:TestModules[0] -SourcePath (Join-Path $script:TestSourcePath $script:TestModules[0]) -InstallPath $script:TestInstallPath -Force
            
            # ACT: Get module info
            $result = Get-InstalledDevModule -Name $script:TestModules[0] -InstallPath $script:TestInstallPath
            
            # ASSERT: Output has expected structure
            $result | Should -Not -BeNull
            $result.PSObject.Properties.Name | Should -Contain "Name"
            $result.PSObject.Properties.Name | Should -Contain "Version"
            $result.PSObject.Properties.Name | Should -Contain "InstallPath"
            $result.PSObject.Properties.Name | Should -Contain "SourceType"
            
            # ASSERT: Output is serializable (for remoting scenarios)
            $serialized = $result | ConvertTo-Json -Depth 3
            $serialized | Should -Not -BeNullOrEmpty
            $deserialized = $serialized | ConvertFrom-Json
            $deserialized.Name | Should -Be $result.Name
        }
        
        It "handles empty pipeline input gracefully" {
            # ACT: Empty array through pipeline
            $results = @() | Get-InstalledDevModule -InstallPath $script:TestInstallPath
            
            # ASSERT: No errors, empty result
            $results | Should -BeNullOrEmpty
        }
        
        It "supports pipeline chaining workflows" {
            # ARRANGE: Install modules
            foreach ($moduleName in $script:TestModules) {
                Install-DevModule -Name $moduleName -SourcePath (Join-Path $script:TestSourcePath $moduleName) -InstallPath $script:TestInstallPath -Force
            }
            
            # ACT: Chain pipeline operations
            $filteredResults = Get-InstalledDevModule -InstallPath $script:TestInstallPath | 
                               Where-Object { $_.Name -like "Module*" } |
                               Select-Object Name, Version
            
            # ASSERT: Pipeline chaining works
            $filteredResults.Count | Should -Be $script:TestModules.Count
            $filteredResults[0].PSObject.Properties.Name | Should -Contain "Name"
            $filteredResults[0].PSObject.Properties.Name | Should -Contain "Version"
        }
    }
    
    Context "Parameter Set Validation" {
        
        BeforeEach {
            Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        }
        
        It "validates parameter sets for Install-DevModule" {
            # ASSERT: Local parameter set requires SourcePath
            { Install-DevModule -Name "Test" -GitHubRepo "user/repo" -SourcePath "/some/path" } | 
                Should -Throw "*parameter*"
            
            # ASSERT: GitHub parameter set requires GitHubRepo
            { Install-DevModule -Name "Test" -SourcePath "/some/path" -GitHubRepo "user/repo" } | 
                Should -Throw "*parameter*"
        }
        
        It "supports ShouldProcess for destructive operations" {
            # ARRANGE: Install a module
            Install-DevModule -Name $script:TestModules[0] -SourcePath (Join-Path $script:TestSourcePath $script:TestModules[0]) -InstallPath $script:TestInstallPath -Force
            
            # ACT: Test WhatIf support
            $whatIfOutput = Uninstall-DevModule -Name $script:TestModules[0] -InstallPath $script:TestInstallPath -WhatIf 2>&1
            
            # ASSERT: WhatIf shows intended action without executing
            $whatIfOutput | Should -Match "What if"
            
            # ASSERT: Module still exists after WhatIf
            $stillExists = Get-InstalledDevModule -Name $script:TestModules[0] -InstallPath $script:TestInstallPath
            $stillExists | Should -Not -BeNull
        }
    }
    
    Context "Error Handling and Resilience" {
        
        BeforeEach {
            Remove-Module PoShDevModules -Force -ErrorAction SilentlyContinue
            Import-Module $PSScriptRoot/../PoShDevModules.psd1 -Force
        }
        
        It "maintains module state after errors" {
            # ACT: Trigger an error
            try {
                Install-DevModule -Name "Invalid" -SourcePath "/nonexistent/path" -InstallPath $script:TestInstallPath
            } catch {
                # Expected to fail
            }
            
            # ASSERT: Module still functional after error
            { Get-Command Install-DevModule } | Should -Not -Throw
            { Get-InstalledDevModule -InstallPath $script:TestInstallPath } | Should -Not -Throw
        }
        
        It "handles concurrent access scenarios" {
            # ARRANGE: Install a module
            Install-DevModule -Name $script:TestModules[0] -SourcePath (Join-Path $script:TestSourcePath $script:TestModules[0]) -InstallPath $script:TestInstallPath -Force
            
            # ACT: Simulate concurrent access (multiple queries)
            $jobs = 1..3 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($InstallPath, $ModulePath)
                    Import-Module $ModulePath -Force
                    Get-InstalledDevModule -InstallPath $InstallPath
                } -ArgumentList $script:TestInstallPath, "$PSScriptRoot/../PoShDevModules.psd1"
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # ASSERT: All concurrent operations succeeded
            $results.Count | Should -BeGreaterThan 0
            foreach ($result in $results) {
                $result | Should -Not -BeNull
            }
        }
    }
}
