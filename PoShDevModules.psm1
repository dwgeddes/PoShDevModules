#Requires -Version 5.1

<#
.SYNOPSIS
    PoShDevModules - PowerShell module for managing development modules

.DESCRIPTION
    This module facilitates limited management of PowerShell modules from local paths 
    or Github repos without needing to publish to NuGet repositories. The purpose is 
    to make it easier to manage modules still under development.

.NOTES
    Author: David Geddes
    Version: 1.0.0
    License: MIT
#>

# Module-level variables
$script:ModuleRoot = $PSScriptRoot
$script:DevModulesPath = if ($IsWindows) { 
    Join-Path $env:USERPROFILE 'Documents\PowerShell\DevModules' 
} else { 
    Join-Path $env:HOME 'Documents/PowerShell/DevModules' 
}

# Import private functions
$Private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)

# Import public functions  
$Public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Private + $Public)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Main entry point function that routes operations based on parameters

.DESCRIPTION
    This function provides the same interface as the original DevModules.ps1 script
    but as a proper PowerShell function that can be called from within the module context.

.PARAMETER SourcePath
    Local path to install a module from.

.PARAMETER GitHubRepo  
    GitHub repository to install from (owner/repo format or full URL).

.PARAMETER Branch
    Git branch to install from (default: main).

.PARAMETER ModuleSubPath
    Subdirectory within the repository containing the module.

.PARAMETER PersonalAccessToken
    GitHub Personal Access Token for private repositories.

.PARAMETER List
    List all installed development modules.

.PARAMETER Remove
    Remove the specified module.

.PARAMETER Update
    Update the specified module from its original source.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER SkipImport
    Don't automatically import after installation.

.PARAMETER InstallPath
    Custom installation directory.

.PARAMETER LogLevel
    Logging verbosity: Silent, Normal, or Verbose.

.EXAMPLE
    Invoke-DevModuleOperation -GitHubRepo "myuser/mymodule" -PersonalAccessToken "ghp_xxxxxxxxxxxx"

.EXAMPLE
    Invoke-DevModuleOperation -SourcePath "C:\Dev\MyModule" -Force

.EXAMPLE
    Invoke-DevModuleOperation -List

.EXAMPLE
    Invoke-DevModuleOperation -Update "MyModule" -PersonalAccessToken "ghp_xxxxxxxxxxxx"

.EXAMPLE
    Invoke-DevModuleOperation -Remove "MyModule"
#>
function Invoke-DevModuleOperation {
    [CmdletBinding(DefaultParameterSetName='Local')]
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Local')]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true, ParameterSetName='GitHub')]
        [string]$GitHubRepo,
        
        [Parameter(ParameterSetName='GitHub')]
        [string]$Branch = 'main',
        
        [Parameter(ParameterSetName='GitHub')]
        [string]$ModuleSubPath = '',
        
        [Parameter(ParameterSetName='GitHub')]
        [Parameter(ParameterSetName='Update')]
        [Alias('PAT', 'GitHubToken')]
        [string]$PersonalAccessToken,
        
        [Parameter(Mandatory=$true, ParameterSetName='List')]
        [switch]$List,
        
        [Parameter(Mandatory=$true, ParameterSetName='Remove')]
        [string]$Remove,
        
        [Parameter(Mandatory=$true, ParameterSetName='Update')]
        [string]$Update,
        
        [switch]$Force,
        [switch]$SkipImport,
        [string]$InstallPath,
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$LogLevel = 'Normal'
    )

    try {
        switch ($PSCmdlet.ParameterSetName) {
            'GitHub' {
                $params = @{
                    GitHubRepo = $GitHubRepo
                    Branch = $Branch
                    ModuleSubPath = $ModuleSubPath
                    Force = $Force
                    SkipImport = $SkipImport
                    LogLevel = $LogLevel
                }
                if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                if ($InstallPath) { $params.InstallPath = $InstallPath }
                
                Install-DevModule @params
            }
            'Local' {
                $params = @{
                    SourcePath = $SourcePath
                    Force = $Force
                    SkipImport = $SkipImport
                    LogLevel = $LogLevel
                }
                if ($InstallPath) { $params.InstallPath = $InstallPath }
                
                Install-DevModule @params
            }
            'List' {
                $modules = Get-InstalledDevModule
                if ($modules) {
                    $modules | Format-Table Name, Version, SourceType, SourcePath, InstallDate -AutoSize
                } else {
                    Write-Host "No development modules found." -ForegroundColor Yellow
                }
            }
            'Remove' {
                Remove-DevModule -Name $Remove -LogLevel $LogLevel
            }
            'Update' {
                $params = @{
                    Name = $Update
                    LogLevel = $LogLevel
                }
                if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                
                Update-DevModule @params
            }
        }
    }
    catch {
        Write-Error "Operation failed: $($_.Exception.Message)"
        throw
    }
}

# Export the public functions
Export-ModuleMember -Function @(
    'Install-DevModule',
    'Get-InstalledDevModule', 
    'Remove-DevModule',
    'Update-DevModule',
    'Invoke-DevModuleOperation'
)
