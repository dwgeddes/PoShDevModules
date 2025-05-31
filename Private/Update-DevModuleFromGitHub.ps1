<#
.SYNOPSIS
    Updates a module from a GitHub source

.DESCRIPTION
    Internal function to handle updating modules from GitHub sources

.PARAMETER Module
    Module metadata object

.PARAMETER PersonalAccessToken
    GitHub PAT for private repos
#>
function Update-DevModuleFromGitHub {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Module,
        
        [string]$PersonalAccessToken
    )

    try {
        Write-Verbose "Updating module '$($Module.Name)' from GitHub: $($Module.SourcePath)"

        # Parse the GitHub repo info
        $repoInfo = Get-GitHubRepoInfo -GitHubRepo $Module.SourcePath
        $branch = if ($Module.Branch) { $Module.Branch } else { 'main' }
        
        Write-Verbose "Downloading latest version from branch: $branch"

        # Create temporary directory for download
        $tempInfo = New-TempDirectory -Prefix "DevModule"
        $tempDir = $tempInfo.Path

        try {
            # Download the repository
            $downloadUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Repo)/archive/refs/heads/$branch.zip"
            $zipPath = Join-Path $tempDir "repo.zip"
            
            Write-Verbose "Downloading from: $downloadUrl"
            
            # Use appropriate method based on whether we have a PAT
            # Suppress progress to prevent hanging in non-interactive environments
            Invoke-WithProgressSuppressed {
                if ($PersonalAccessToken) {
                    try {
                        # Secure API key handling - create headers and clean up after use
                        $headers = @{ Authorization = "token $PersonalAccessToken" }
                        Invoke-RestMethod -Uri $downloadUrl -OutFile $zipPath -Headers $headers
                    } finally {
                        # Security: Clear sensitive data from memory
                        if ($headers) {
                            $headers.Clear()
                            $headers = $null
                        }
                    }
                } else {
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
                }
            }

            Write-Verbose "Downloaded repository archive"

            # Extract the archive
            $extractPath = Join-Path $tempDir "extracted"
            Invoke-WithProgressSuppressed {
                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            }
            Write-Verbose "Extracted repository archive"

            # Find the actual module directory
            $repoDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
            $sourcePath = $repoDir.FullName
            
            if ($Module.ModuleSubPath) {
                $sourcePath = Join-Path $sourcePath $Module.ModuleSubPath
                if (-not (Test-Path $sourcePath)) {
                    throw "Module subdirectory not found: $($Module.ModuleSubPath)"
                }
            }

            Write-Verbose "Module source path: $sourcePath"

            # Validate that module files exist
            $manifestFiles = Get-ChildItem -Path $sourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
            if ($manifestFiles.Count -eq 0) {
                throw "No PowerShell module manifest (.psd1) found in: $sourcePath"
            }

            # Extract version information from new manifest
            $manifestFile = $manifestFiles[0]
            $newVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
            
            Write-Verbose "Found module manifest: $($manifestFile.Name)"
            Write-Verbose "Updating to version: $newVersion"

            # Extract install base path from Module.InstallPath (remove old version directory if present)
            $installBasePath = Split-Path $Module.InstallPath -Parent
            if ((Split-Path $installBasePath -Leaf) -eq $Module.Name) {
                # Module.InstallPath included version directory, installBasePath is the module base path
                $moduleBasePath = $installBasePath
                $installBasePath = Split-Path $moduleBasePath -Parent
            } else {
                # Module.InstallPath was already the base path (unusual)
                $moduleBasePath = Join-Path $installBasePath $Module.Name
            }

            # Create new version-specific destination path
            $newDestinationPath = Join-Path $moduleBasePath $newVersion

            # Remove existing version directory if it exists
            if (Test-Path $newDestinationPath) {
                if ($PSCmdlet.ShouldProcess($newDestinationPath, "Remove existing version directory")) {
                    Remove-Item -Path $newDestinationPath -Recurse -Force
                    Write-Verbose "Removed existing version directory: $newDestinationPath"
                }
            }

            # Create new version directory
            if ($PSCmdlet.ShouldProcess($newDestinationPath, "Create new version directory")) {
                New-Item -Path $newDestinationPath -ItemType Directory -Force | Out-Null
            }
            Write-Verbose "Created new version directory: $newDestinationPath"

            # Copy updated files
            if ($PSCmdlet.ShouldProcess($newDestinationPath, "Copy updated module files")) {
                Invoke-WithProgressSuppressed {
                    Copy-Item -Path (Join-Path $sourcePath '*') -Destination $newDestinationPath -Recurse -Force
                }
                Write-Verbose "Copied updated module files"
            }

            # Update metadata with new version and path
            if ($PSCmdlet.ShouldProcess($Module.Name, "Update module metadata")) {
                Save-ModuleManifest -ModuleName $Module.Name -SourceType 'GitHub' -SourcePath $Module.SourcePath -InstallPath $installBasePath -Branch $Module.Branch
            }

            # Reload module if it's currently loaded, but avoid self-reload during pipeline execution
            $currentModule = Get-Module -Name $Module.Name -ErrorAction SilentlyContinue
            if ($currentModule) {
                # Check if we're updating the same module that's currently executing the update
                $isUpdatingSelf = $currentModule.Name -eq 'PoShDevModules' -and $Module.Name -eq 'PoShDevModules'
                
                if (-not $isUpdatingSelf) {
                    Remove-Module -Name $Module.Name -Force
                    $ProgressPreference = 'SilentlyContinue'
                    Import-Module $Module.Name -Force
                    Write-Verbose "Reloaded module in current session"
                } else {
                    Write-Warning "Skipping module reload during self-update to avoid breaking pipeline execution. Please restart PowerShell session to load the updated module."
                }
            }

            Write-Verbose "Successfully updated module '$($Module.Name)' to version '$newVersion' from GitHub"
            
            # Return the updated module object
            $updatedModule = Get-InstalledDevModule -Name $Module.Name -InstallPath $installBasePath
            return $updatedModule
        }
        finally {
            # Clean up temporary directory
            & $tempInfo.Cleanup
        }
    }
    catch {
        throw "Failed to update module from GitHub: $($_.Exception.Message)"
    }
}
