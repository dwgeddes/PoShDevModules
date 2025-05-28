BeforeAll {
    # Import the module for testing
    $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module "$ModuleRoot\PoShDevModules.psd1" -Force
}

Describe "Invoke-DevModuleOperation" {
    
    Context "Parameter Set Validation" {
        It "Should accept List parameter" {
            { Get-Command Invoke-DevModuleOperation -ParameterName List } | Should -Not -Throw
        }
        
        It "Should accept SourcePath parameter" {
            { Get-Command Invoke-DevModuleOperation -ParameterName SourcePath } | Should -Not -Throw
        }
        
        It "Should accept GitHubRepo parameter" {
            { Get-Command Invoke-DevModuleOperation -ParameterName GitHubRepo } | Should -Not -Throw
        }
        
        It "Should accept Remove parameter" {
            { Get-Command Invoke-DevModuleOperation -ParameterName Remove } | Should -Not -Throw
        }
        
        It "Should accept Update parameter" {
            { Get-Command Invoke-DevModuleOperation -ParameterName Update } | Should -Not -Throw
        }
        
        It "Should have mutually exclusive parameter sets" {
            $cmd = Get-Command Invoke-DevModuleOperation
            $parameterSets = $cmd.ParameterSets
            $parameterSets.Count | Should -BeGreaterThan 1
            
            # Verify parameter sets exist
            $listSet = $parameterSets | Where-Object { $_.Name -eq 'List' }
            $localSet = $parameterSets | Where-Object { $_.Name -eq 'Local' }
            $githubSet = $parameterSets | Where-Object { $_.Name -eq 'GitHub' }
            $removeSet = $parameterSets | Where-Object { $_.Name -eq 'Remove' }
            $updateSet = $parameterSets | Where-Object { $_.Name -eq 'Update' }
            
            $listSet | Should -Not -BeNullOrEmpty
            $localSet | Should -Not -BeNullOrEmpty
            $githubSet | Should -Not -BeNullOrEmpty
            $removeSet | Should -Not -BeNullOrEmpty
            $updateSet | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "List Operation" {
        It "Should execute Get-InstalledDevModule when List parameter is used" {
            # Mock Get-InstalledDevModule to avoid actual module operations
            Mock Get-InstalledDevModule { 
                return @(
                    [PSCustomObject]@{
                        Name = 'TestModule1'
                        Version = '1.0.0'
                        SourceType = 'GitHub'
                        SourcePath = 'user/repo'
                        InstallPath = '/test/path'
                        InstallDate = Get-Date
                        Branch = 'main'
                        LastUpdated = Get-Date
                        LatestVersionPath = '/test/path/TestModule1/1.0.0'
                    }
                )
            } -ModuleName PoShDevModules
            
            $result = Invoke-DevModuleOperation -List
            
            Should -Invoke Get-InstalledDevModule -ModuleName PoShDevModules -Exactly 1
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -Be 'TestModule1'
        }
    }
    
    Context "Install Operation" {
        It "Should call Install-DevModule with correct parameters for GitHub source" {
            Mock Install-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -GitHubRepo 'user/repo'
            
            Should -Invoke Install-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $GitHubRepo -eq 'user/repo'
            }
        }
        
        It "Should call Install-DevModule with correct parameters for local source" {
            Mock Install-DevModule { } -ModuleName PoShDevModules
            
            # Create a temporary directory for testing
            $tempPath = Join-Path $TestDrive 'TestModule'
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
            
            Invoke-DevModuleOperation -SourcePath $tempPath
            
            Should -Invoke Install-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $SourcePath -eq $tempPath
            }
        }
        
        It "Should call Install-DevModule with additional parameters when provided" {
            Mock Install-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -GitHubRepo 'user/repo' -InstallPath '/custom/path' -Force -SkipImport -Branch 'develop'
            
            Should -Invoke Install-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $GitHubRepo -eq 'user/repo' -and
                $InstallPath -eq '/custom/path' -and
                $Force -eq $true -and
                $SkipImport -eq $true -and
                $Branch -eq 'develop'
            }
        }
        
        It "Should call Install-DevModule without InstallPath when not provided" {
            Mock Install-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -GitHubRepo 'user/repo'
            
            Should -Invoke Install-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $GitHubRepo -eq 'user/repo' -and
                -not $PSBoundParameters.ContainsKey('InstallPath')
            }
        }
    }
    
    Context "Remove Operation" {
        It "Should call Uninstall-DevModule with correct module name" {
            Mock Uninstall-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -Remove 'TestModule'
            
            Should -Invoke Uninstall-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $Name -eq 'TestModule'
            }
        }
    }
    
    Context "Update Operation" {
        It "Should call Update-DevModule with correct module name" {
            Mock Update-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -Update 'TestModule'
            
            Should -Invoke Update-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $Name -eq 'TestModule'
            }
        }
        
        It "Should call Update-DevModule with Force parameter when provided" {
            Mock Update-DevModule { } -ModuleName PoShDevModules
            
            Invoke-DevModuleOperation -Update 'TestModule' -Force
            
            Should -Invoke Update-DevModule -ModuleName PoShDevModules -Exactly 1 -ParameterFilter {
                $Name -eq 'TestModule' -and
                $Force -eq $true
            }
        }
    }
    
    Context "Parameter Validation" {
        It "Should require at least one parameter" {
            $cmd = Get-Command Invoke-DevModuleOperation
            $mandatoryParams = $cmd.ParameterSets | ForEach-Object { 
                $_.Parameters | Where-Object { $_.IsMandatory } | Select-Object -ExpandProperty Name 
            }
            $mandatoryParams | Should -Contain 'List'
            $mandatoryParams | Should -Contain 'SourcePath'
            $mandatoryParams | Should -Contain 'GitHubRepo'
            $mandatoryParams | Should -Contain 'Remove'
            $mandatoryParams | Should -Contain 'Update'
        }
        
        It "Should throw error when GitHubRepo parameter is empty" {
            { Invoke-DevModuleOperation -GitHubRepo '' } | Should -Throw
        }
        
        It "Should accept valid SourcePath parameter" {
            Mock Install-DevModule { } -ModuleName PoShDevModules
            
            # Create a temporary directory for testing
            $tempPath = Join-Path $TestDrive 'TestModule'
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
            
            { Invoke-DevModuleOperation -SourcePath $tempPath } | Should -Not -Throw
        }
        
        It "Should throw error when Remove parameter is empty" {
            { Invoke-DevModuleOperation -Remove '' } | Should -Throw
        }
        
        It "Should throw error when Update parameter is empty" {
            { Invoke-DevModuleOperation -Update '' } | Should -Throw
        }
    }
    
    Context "Help and Documentation" {
        It "Should have proper help content" {
            $help = Get-Help Invoke-DevModuleOperation
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
            $help.Examples | Should -Not -BeNullOrEmpty
        }
        
        It "Should have examples that can be parsed" {
            $help = Get-Help Invoke-DevModuleOperation -Examples
            $help.Examples.Example.Count | Should -BeGreaterThan 0
            
            foreach ($example in $help.Examples.Example) {
                $example.Code | Should -Not -BeNullOrEmpty
                $example.Remarks | Should -Not -BeNullOrEmpty
            }
        }
    }
}
