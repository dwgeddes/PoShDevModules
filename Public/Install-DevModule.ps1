<#
.SYNOPSIS
    Installs a PowerShell module from a local path or GitHub repository

.DESCRIPTION
    This function installs a PowerShell module for development purposes from either
    a local filesystem path or a GitHub repository. The module is installed to a
    development modules directory for easy management.

.PARAMETER SourcePath
    Local filesystem path containing the module to install

.PARAMETER GitHubRepo
    GitHub repository to install from (format: owner/repo or full URL)

.PARAMETER Branch
    Git branch to install from (default: main)

.PARAMETER ModuleSubPath
    Subdirectory within the repository containing the module

.PARAMETER PersonalAccessToken
    GitHub Personal Access Token for accessing private repositories

.PARAMETER Force
    Skip confirmation prompts and overwrite existing installations

.PARAMETER SkipImport
    Don't automatically import the module after installation

.PARAMETER InstallPath
    Custom installation directory (default: ~/Documents/PowerShell/DevModules)

.PARAMETER LogLevel
    Logging verbosity level: Silent, Normal, or Verbose

.EXAMPLE
    Install-DevModule -GitHubRepo "myuser/mymodule" -PersonalAccessToken "ghp_xxxxxxxxxxxx"

.EXAMPLE
    Install-DevModule -SourcePath "C:\Dev\MyModule" -Force

.EXAMPLE
    Install-DevModule -GitHubRepo "myuser/mymodule" -Branch "develop" -ModuleSubPath "src/MyModule"
#>
function Install-DevModule {
    [CmdletBinding(DefaultParameterSetName='Local')]
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Local')]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true, ParameterSetName='GitHub')]
        [string]$GitHubRepo,
        
        [Parameter(ParameterSetName='GitHub')]
        [string]$Branch = 'main',
        
        [Parameter(ParameterSetName='GitHub')]
        [string]$ModuleSubPath = '',
        
        [Parameter(ParameterSetName='GitHub')]
        [Alias('PAT', 'GitHubToken')]
        [string]$PersonalAccessToken,
        
        [switch]$Force,
        [switch]$SkipImport,
        
        [string]$InstallPath,
        
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$LogLevel = 'Normal'
    )

    begin {
        if (-not $InstallPath) {
            $InstallPath = if ($IsWindows) { 
                Join-Path $env:USERPROFILE 'Documents\PowerShell\DevModules' 
            } else { 
                Join-Path $env:HOME 'Documents/PowerShell/DevModules' 
            }
        }
        Write-LogMessage "Starting module installation..." $LogLevel "Normal"
        
        # Ensure install directory exists
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            Write-LogMessage "Created install directory: $InstallPath" $LogLevel "Normal"
        }
    }

    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'Local' {
                    Install-DevModuleFromLocal -SourcePath $SourcePath -InstallPath $InstallPath -Force:$Force -SkipImport:$SkipImport -LogLevel $LogLevel
                }
                'GitHub' {
                    $params = @{
                        GitHubRepo = $GitHubRepo
                        Branch = $Branch
                        InstallPath = $InstallPath
                        Force = $Force
                        SkipImport = $SkipImport
                        LogLevel = $LogLevel
                    }
                    if ($ModuleSubPath) { $params.ModuleSubPath = $ModuleSubPath }
                    if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                    
                    Install-DevModuleFromGitHub @params
                }
            }
        }
        catch {
            Write-Error "Failed to install module: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-LogMessage "Module installation completed." $LogLevel "Normal"
    }
}
