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
        
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'List', Justification = 'Parameter is used to determine parameter set and control flow')]
        [Parameter(Mandatory=$true, ParameterSetName='List')]
        [switch]$List,
        
        [Parameter(Mandatory=$true, ParameterSetName='Remove')]
        [string]$Remove,
        
        [Parameter(Mandatory=$true, ParameterSetName='Update')]
        [string]$Update,
        
        [switch]$Force,
        [switch]$SkipImport,
        [string]$InstallPath
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
                }
                if ($InstallPath) { $params.InstallPath = $InstallPath }
                
                Install-DevModule @params
            }
            'List' {
                # The List parameter determines this parameter set
                Write-Verbose "Listing installed modules (triggered by List parameter: $List)"
                Get-InstalledDevModule
            }
            'Remove' {
                Uninstall-DevModule -Name $Remove
            }
            'Update' {
                $params = @{
                    Name = $Update
                }
                if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                if ($Force) { $params.Force = $Force }
                if ($InstallPath) { $params.InstallPath = $InstallPath }
                
                Update-DevModule @params
            }
        }
    }
    catch {
        Write-Error "Operation failed: $($_.Exception.Message)"
        throw
    }
}
