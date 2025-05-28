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
        [switch]$SkipImport
    )

    try {
        # Parse GitHub repo URL/format
        $repoInfo = Get-GitHubRepoInfo -GitHubRepo $GitHubRepo
        Write-Verbose "Downloading from GitHub: $($repoInfo.Owner)/$($repoInfo.Repo)"

        # Create temporary directory for download
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DevModule_$(Get-Random)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created temporary directory: $tempDir"

        try {
            # Download the repository
            $downloadUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Repo)/archive/refs/heads/$Branch.zip"
            $zipPath = Join-Path $tempDir "repo.zip"
            
            Write-Verbose "Downloading from: $downloadUrl"
            
            # Use appropriate method based on whether we have a PAT
            if ($PersonalAccessToken) {
                $headers = @{ Authorization = "token $PersonalAccessToken" }
                Invoke-RestMethod -Uri $downloadUrl -OutFile $zipPath -Headers $headers
            } else {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
            }

            Write-Verbose "Downloaded repository archive"

            # Extract the archive
            $extractPath = Join-Path $tempDir "extracted"
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            Write-Verbose "Extracted repository archive"

            # Find the actual module directory
            $repoDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
            $sourcePath = $repoDir.FullName
            
            if ($ModuleSubPath) {
                $sourcePath = Join-Path $sourcePath $ModuleSubPath
                if (-not (Test-Path $sourcePath)) {
                    throw "Module subdirectory not found: $ModuleSubPath"
                }
            }

            Write-Verbose "Module source path: $sourcePath"

            # Find module manifest
            $manifestFiles = Get-ChildItem -Path $sourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
            if ($manifestFiles.Count -eq 0) {
                throw "No PowerShell module manifest (.psd1) found in: $sourcePath"
            }

            $manifestFile = $manifestFiles[0]
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestFile.Name)
            $moduleVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
            
            Write-Verbose "Found module: $moduleName, Version: $moduleVersion"

            # Create version-specific destination path: InstallPath/ModuleName/Version/
            $moduleBasePath = Join-Path $InstallPath $moduleName
            $destinationPath = Join-Path $moduleBasePath $moduleVersion

            # Check if module already exists
            if ((Test-Path $destinationPath) -and -not $Force) {
                throw "Module '$moduleName' version '$moduleVersion' already exists at $destinationPath. Use -Force to overwrite."
            }

            # Create destination directory (including version directory)
            if (Test-Path $destinationPath) {
                Remove-Item -Path $destinationPath -Recurse -Force
                Write-Verbose "Removed existing module version directory"
            }

            New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null

            # Copy module files
            Copy-Item -Path (Join-Path $sourcePath '*') -Destination $destinationPath -Recurse -Force
            Write-Verbose "Copied module files to: $destinationPath"

            # Save metadata
            Save-ModuleManifest -ModuleName $moduleName -SourceType 'GitHub' -SourcePath "$($repoInfo.Owner)/$($repoInfo.Repo)" -InstallPath $InstallPath -Branch $Branch -ModuleSubPath $ModuleSubPath

            # Import module if requested - PowerShell will auto-discover the latest version
            if (-not $SkipImport) {
                try {
                    Import-Module $moduleName -Force
                    Write-Verbose "Imported module: $moduleName"
                }
                catch {
                    Write-Warning "Module installed but failed to import: $($_.Exception.Message)"
                }
            }

            Write-Verbose "Successfully installed module '$moduleName' from GitHub"
            
            # Return the installed module object
            $installedModule = Get-InstalledDevModule -Name $moduleName -InstallPath $InstallPath
            return $installedModule
        }
        finally {
            # Clean up temporary directory
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Cleaned up temporary directory"
            }
        }
    }
    catch {
        throw "Failed to install module from GitHub: $($_.Exception.Message)"
    }
}
