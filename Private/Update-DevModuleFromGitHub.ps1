<#
.SYNOPSIS
    Updates a module from a GitHub source

.DESCRIPTION
    Internal function to handle updating modules from GitHub sources

.PARAMETER Module
    Module metadata object

.PARAMETER PersonalAccessToken
    GitHub PAT for private repos

.PARAMETER LogLevel
    Logging level
#>
function Update-DevModuleFromGitHub {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Module,
        
        [string]$PersonalAccessToken,
        [string]$LogLevel
    )

    try {
        Write-LogMessage "Updating module '$($Module.Name)' from GitHub: $($Module.SourcePath)" $LogLevel "Normal"

        # Parse the GitHub repo info
        $repoInfo = Get-GitHubRepoInfo -GitHubRepo $Module.SourcePath
        $branch = if ($Module.Branch) { $Module.Branch } else { 'main' }
        
        Write-LogMessage "Downloading latest version from branch: $branch" $LogLevel "Verbose"

        # Create temporary directory for download
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DevModule_$(Get-Random)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-LogMessage "Created temporary directory: $tempDir" $LogLevel "Verbose"

        try {
            # Download the repository
            $downloadUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Repo)/archive/refs/heads/$branch.zip"
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
            
            if ($Module.ModuleSubPath) {
                $sourcePath = Join-Path $sourcePath $Module.ModuleSubPath
                if (-not (Test-Path $sourcePath)) {
                    throw "Module subdirectory not found: $($Module.ModuleSubPath)"
                }
            }

            Write-LogMessage "Module source path: $sourcePath" $LogLevel "Verbose"

            # Validate that module files exist
            $manifestFiles = Get-ChildItem -Path $sourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
            if ($manifestFiles.Count -eq 0) {
                throw "No PowerShell module manifest (.psd1) found in: $sourcePath"
            }

            # Remove existing module directory
            if (Test-Path $Module.InstallPath) {
                Remove-Item -Path $Module.InstallPath -Recurse -Force
                Write-LogMessage "Removed existing module directory" $LogLevel "Verbose"
            }

            # Create new directory
            New-Item -Path $Module.InstallPath -ItemType Directory -Force | Out-Null

            # Copy updated files
            Copy-Item -Path "$sourcePath\*" -Destination $Module.InstallPath -Recurse -Force
            Write-LogMessage "Copied updated module files" $LogLevel "Normal"

            # Reload module if it's currently loaded
            if (Get-Module -Name $Module.Name -ErrorAction SilentlyContinue) {
                Remove-Module -Name $Module.Name -Force
                Import-Module $Module.InstallPath -Force
                Write-LogMessage "Reloaded module in current session" $LogLevel "Normal"
            }

            Write-LogMessage "Successfully updated module '$($Module.Name)' from GitHub" $LogLevel "Normal"
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
        throw "Failed to update module from GitHub: $($_.Exception.Message)"
    }
}
