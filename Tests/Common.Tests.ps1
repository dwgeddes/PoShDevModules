# Common test configuration and utilities for PoShDevModules tests
# This file should be dot-sourced at the beginning of all test files

# Mock common interactive operations to prevent test hanging
function Initialize-TestEnvironment {
    [CmdletBinding()]
    param()

    # MANDATORY: Set preference variables to prevent hanging
    $global:ConfirmPreference = 'None'
    $global:ProgressPreference = 'SilentlyContinue'
    
    # Simple mocks for interactive operations - no module scope to avoid Pester issues
    Mock Read-Host { 
        param($Prompt)
        Write-Verbose "Mock Read-Host called with: $Prompt"
        return "MockedInput" 
    }
    
    Mock Get-Credential { 
        param($UserName, $Message)
        Write-Verbose "Mock Get-Credential called for: $UserName"
        $password = ConvertTo-SecureString "MockedPassword123!" -AsPlainText -Force
        return New-Object PSCredential("MockedUser", $password)
    }
    
    Mock Write-Progress { 
        param($Activity, $Status, $PercentComplete)
        Write-Verbose "Mock Write-Progress: $Activity - $Status"
    }

    # Mock Invoke-RestMethod for GitHub API calls
    Mock Invoke-RestMethod {
        param($Uri, $Method, $Headers, $Body)
        Write-Verbose "Mock Invoke-RestMethod called for: $Uri"
        
        if ($Uri -match 'api.github.com/repos/([^/]+)/([^/]+)') {
            return @{
                name = $Matches[2]
                owner = @{ login = $Matches[1] }
                default_branch = 'main'
            }
        }
        elseif ($Uri -match 'archive/refs/heads/') {
            # Return a dummy archive content (will be mocked further in tests)
            return [System.Text.Encoding]::UTF8.GetBytes("Mock archive content")
        }
        else {
            throw "Unexpected GitHub API call to: $Uri"
        }
    } -ModuleName 'PoShDevModules'
    
    # MANDATORY: Prevent confirmation prompts
    $global:ConfirmPreference = 'None'
    $global:ProgressPreference = 'SilentlyContinue'
    
    # Create test directory for TestDrive
    $testModuleRoot = Join-Path $TestDrive "TestModules"
    New-Item -Path $testModuleRoot -ItemType Directory -Force | Out-Null
    
    return $testModuleRoot
}

# Create a test module for testing installation and updates
function New-TestModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [string]$Version = "1.0.0",
        
        [string[]]$Functions = @("Get-TestFunction", "Set-TestFunction")
    )
    
    # Create module directory
    $modulePath = Join-Path $Path $ModuleName
    New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
    
    # Create module manifest
    $manifestPath = Join-Path $modulePath "$ModuleName.psd1"
    $guid = [Guid]::NewGuid().ToString()
    
    $manifestContent = @"
@{
    RootModule = '$ModuleName.psm1'
    ModuleVersion = '$Version'
    GUID = '$guid'
    Author = 'Test Author'
    Description = 'Test module for PoShDevModules testing'
    FunctionsToExport = @('$($Functions -join "', '")')
    PrivateData = @{
        PSData = @{
            Tags = @('Test')
            ProjectUri = 'https://github.com/test/$ModuleName'
        }
    }
}
"@
    
    Set-Content -Path $manifestPath -Value $manifestContent -Force
    
    # Create module script
    $moduleScript = @"
function Get-TestFunction {
    [CmdletBinding()]
    param()
    
    return @{
        Name = '$ModuleName'
        Version = '$Version'
        Status = 'Working'
        Timestamp = Get-Date
    }
}

function Set-TestFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]`$Value
    )
    
    Write-Output "Value set to: `$Value"
}

# Export functions
Export-ModuleMember -Function $($Functions -join ', ')
"@
    
    $psm1Path = Join-Path $modulePath "$ModuleName.psm1"
    Set-Content -Path $psm1Path -Value $moduleScript -Force
    
    # Create a simple README
    $readmePath = Join-Path $modulePath "README.md"
    $readmeContent = @"
# $ModuleName

Test module created for PoShDevModules testing.
Version: $Version
"@
    
    Set-Content -Path $readmePath -Value $readmeContent -Force
    
    return $modulePath
}

# Helper function for test validation
function Test-ModuleInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$InstallPath
    )
    
    # Check if module appears in Get-InstalledDevModule
    $module = Get-InstalledDevModule -Name $ModuleName -InstallPath $InstallPath -ErrorAction SilentlyContinue
    if (-not $module) {
        return $false
    }
    
    # Check if files exist
    $modulePath = Join-Path $InstallPath $ModuleName
    if (-not (Test-Path $modulePath)) {
        return $false
    }
    
    $manifestPath = Join-Path $modulePath "$ModuleName.psd1"
    if (-not (Test-Path $manifestPath)) {
        return $false
    }
    
    return $true
}
