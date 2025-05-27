<#
.SYNOPSIS
    Installs a module from a GitHub repository

.DESCRIPTION
    Internal function to handle installation from GitHub sources

.PARAMETER GitHubRepo
    GitHub repository (owner/repo format)

.PARAMETER Branch
    Git branch to install from

.PARAMETER ModuleSubPath
    Subdirectory containing the module

.PARAMETER PersonalAccessToken
    GitHub PAT for private repos

.PARAMETER InstallPath
    Where to install the module

.PARAMETER Force
    Whether to force overwrite existing modules

.PARAMETER SkipImport
    Whether to skip importing after installation

.PARAMETER LogLevel
    Logging level
#>
function Install-DevModuleFromGitHub {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GitHubRepo,
        
        [string]$Branch = 'main',
        [string]$ModuleSubPath = '',
        [string]$PersonalAccessToken,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        
        [switch]$Force,
        [switch]$SkipImport,
        [string]$LogLevel
    )

    try {
        # Parse GitHub repo URL/format
        $repoInfo = Get-GitHubRepoInfo -GitHubRepo $GitHubRepo
        Write-LogMessage "Downloading from GitHub: $($repoInfo.Owner)/$($repoInfo.Repo)" $LogLevel "Normal"

        # Create temporary directory for download
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DevModule_$(Get-Random)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-LogMessage "Created temporary directory: $tempDir" $LogLevel "Verbose"

        try {
            # Download the repository
            $downloadUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Repo)/archive/refs/heads/$Branch.zip"
            $zipPath = Join-Path $tempDir "repo.zip"
            
            Write-LogMessage "Downloading from: $downloadUrl" $LogLevel "Verbose"
            
            # Use appropriate method based on whether we have a PAT
            if ($PersonalAccessToken) {
                $headers = @{ Authorization = "token $PersonalAccessToken" }
                Invoke-RestMethod -Uri $downloadUrl -OutFile $zipPath -Headers $headers
            } else {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
            }

            Write-LogMessage "Downloaded repository archive" $LogLevel "Normal"

            # Extract the archive
            $extractPath = Join-Path $tempDir "extracted"
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            Write-LogMessage "Extracted repository archive" $LogLevel "Verbose"

            # Find the actual module directory
            $repoDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
            $sourcePath = $repoDir.FullName
            
            if ($ModuleSubPath) {
                $sourcePath = Join-Path $sourcePath $ModuleSubPath
                if (-not (Test-Path $sourcePath)) {
                    throw "Module subdirectory not found: $ModuleSubPath"
                }
            }

            Write-LogMessage "Module source path: $sourcePath" $LogLevel "Verbose"

            # Find module manifest
            $manifestFiles = Get-ChildItem -Path $sourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
            if ($manifestFiles.Count -eq 0) {
                throw "No PowerShell module manifest (.psd1) found in: $sourcePath"
            }

            $manifestFile = $manifestFiles[0]
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestFile.Name)
            
            Write-LogMessage "Found module: $moduleName" $LogLevel "Normal"

            $destinationPath = Join-Path $InstallPath $moduleName

            # Check if module already exists
            if ((Test-Path $destinationPath) -and -not $Force) {
                throw "Module '$moduleName' already exists at $destinationPath. Use -Force to overwrite."
            }

            # Create destination directory
            if (Test-Path $destinationPath) {
                Remove-Item -Path $destinationPath -Recurse -Force
                Write-LogMessage "Removed existing module directory" $LogLevel "Verbose"
            }

            New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null

            # Copy module files
            Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Recurse -Force
            Write-LogMessage "Copied module files to: $destinationPath" $LogLevel "Normal"

            # Save metadata
            $metadata = @{
                SourceType = 'GitHub'
                SourcePath = "$($repoInfo.Owner)/$($repoInfo.Repo)"
                Branch = $Branch
                ModuleSubPath = $ModuleSubPath
            }
            Save-ModuleMetadata -ModuleName $moduleName -SourceType 'GitHub' -SourcePath "$($repoInfo.Owner)/$($repoInfo.Repo)" -InstallPath $InstallPath -Branch $Branch -ModuleSubPath $ModuleSubPath -LogLevel $LogLevel

            # Import module if requested
            if (-not $SkipImport) {
                try {
                    Import-Module $destinationPath -Force
                    Write-LogMessage "Imported module: $moduleName" $LogLevel "Normal"
                }
                catch {
                    Write-Warning "Module installed but failed to import: $($_.Exception.Message)"
                }
            }

            Write-LogMessage "Successfully installed module '$moduleName' from GitHub" $LogLevel "Normal"
        }
        finally {
            # Clean up temporary directory
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-LogMessage "Cleaned up temporary directory" $LogLevel "Verbose"
            }
        }
    }
    catch {
        throw "Failed to install module from GitHub: $($_.Exception.Message)"
    }
}
