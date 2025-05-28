<#
.SYNOPSIS
    Installs a development module from a local path or GitHub repository.

.DESCRIPTION
    This function facilitates the installation of development modules from local paths or GitHub repositories.
    It supports parameter validation, error handling, and optional pipeline input.

.PARAMETER SourcePath
    The local path to the module source.

.PARAMETER GitHubRepo
    The GitHub repository containing the module.

.PARAMETER InstallPath
    The path where the module will be installed.

.PARAMETER Force
    Forces the installation, overwriting existing files if necessary.

.PARAMETER SkipImport
    Skips importing the module after installation.

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
        [string]$InstallPath
    )

    begin {
        # Validate parameters using standardized validation
        try {
            $validationParams = @{}
            if ($PSCmdlet.ParameterSetName -eq 'GitHub') { 
                $validationParams.GitHubRepo = $GitHubRepo 
            }
            if ($PSCmdlet.ParameterSetName -eq 'Local') { 
                $validationParams.SourcePath = $SourcePath 
            }
            if ($InstallPath) { 
                $validationParams.InstallPath = $InstallPath 
            }
            if ($Name) {
                $validationParams.Name = $Name
            }
            Test-StandardParameter @validationParams
        }
        catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "validate installation parameters" -WriteToHost
            return
        }
        
        if (-not $InstallPath) {
            $InstallPath = Get-DevModulesPath
        }
        Write-Verbose "Starting module installation..."
        
        # Ensure install directory exists
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created install directory: $InstallPath"
        }
    }

    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'Local' {
                    Install-DevModuleFromLocal -SourcePath $SourcePath -InstallPath $InstallPath -Force:$Force -SkipImport:$SkipImport
                }
                'GitHub' {
                    $params = @{
                        GitHubRepo = $GitHubRepo
                        Branch = $Branch
                        InstallPath = $InstallPath
                        Force = $Force
                        SkipImport = $SkipImport
                    }
                    if ($ModuleSubPath) { $params.ModuleSubPath = $ModuleSubPath }
                    if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                    
                    Install-DevModuleFromGitHub @params
                }
            }
        }
        catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "install module" -WriteToHost
            return
        }
    }

    end {
        Write-Verbose "Module installation completed."
    }
}
