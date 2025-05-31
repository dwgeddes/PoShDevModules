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
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Local')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(ParameterSetName='Local', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='GitHub', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true, ParameterSetName='Local')]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true, ParameterSetName='GitHub')]
        [ValidateScript({
            if ($_ -match '^([a-zA-Z0-9._-]+)/([a-zA-Z0-9._-]+)$' -or 
                $_ -match '^https://github\.com/([a-zA-Z0-9._-]+)/([a-zA-Z0-9._-]+)(?:\.git)?/?$') {
                $true
            } else {
                throw "GitHubRepo must be in format 'owner/repo' or a valid GitHub URL"
            }
        })]
        [string]$GitHubRepo,
        
        [Parameter(ParameterSetName='GitHub')]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) { $true }
            elseif ($_ -match '^[a-zA-Z0-9._/-]+$') { $true }
            else { throw "Branch name contains invalid characters" }
        })]
        [string]$Branch = 'main',
        
        [Parameter(ParameterSetName='GitHub')]
        [string]$ModuleSubPath = '',
        
        [Parameter(ParameterSetName='GitHub')]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) { $true }
            elseif ($_ -match '^gh[ps]_[A-Za-z0-9_]{36,}$') { $true }
            else { throw "PersonalAccessToken must be a valid GitHub token format (ghp_ or ghs_ prefix)" }
        })]
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
        if ($PSCmdlet.ShouldProcess($InstallPath, "Install development module")) {
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
    }

    end {
        Write-Verbose "Module installation completed."
    }
}
