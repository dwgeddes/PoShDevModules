<#
.SYNOPSIS
    Saves module metadata for tracking installations

.DESCRIPTION
    Internal function to save installation metadata for development modules

.PARAMETER ModuleName
    Name of the module

.PARAMETER SourceType
    Type of source (Local or GitHub)

.PARAMETER SourcePath
    Original source path or repository

.PARAMETER InstallPath
    Base installation path

.PARAMETER Branch
    Git branch (for GitHub sources)

.PARAMETER ModuleSubPath
    Module subdirectory path
#>
function Save-ModuleMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Local', 'GitHub')]
        [string]$SourceType,
        
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        
        [string]$Branch,
        [string]$ModuleSubPath
    )

    try {
        $metadataDir = Join-Path $InstallPath '.metadata'
        if (-not (Test-Path $metadataDir)) {
            New-Item -Path $metadataDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created metadata directory: $metadataDir"
        }

        # Try to get module version from manifest in version-specific directory structure
        $moduleBasePath = Join-Path $InstallPath $ModuleName
        $version = "Unknown"
        $latestVersionPath = $null
        
        # Find the latest version directory
        if (Test-Path $moduleBasePath) {
            $versionDirs = Get-ChildItem -Path $moduleBasePath -Directory | Sort-Object Name -Descending
            if ($versionDirs.Count -gt 0) {
                $latestVersionPath = $versionDirs[0].FullName
                $versionDirName = $versionDirs[0].Name
                
                # Try to get version from manifest file first
                $manifestPath = Join-Path $latestVersionPath "$ModuleName.psd1"
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Import-PowerShellDataFile $manifestPath
                        $version = $manifest.ModuleVersion
                        Write-Verbose "Found module version from manifest: $version"
                    }
                    catch {
                        # Fall back to directory name if manifest exists but can't be read
                        $version = $versionDirName
                        Write-Verbose "Could not read version from manifest, using directory name: $version"
                    }
                } else {
                    # Fall back to directory name if no manifest file
                    $version = $versionDirName
                    Write-Verbose "No manifest found, using directory name: $version"
                }
            }
        }

        $metadata = @{
            Name = $ModuleName
            Version = $version
            SourceType = $SourceType
            SourcePath = $SourcePath
            InstallPath = $moduleBasePath
            InstallDate = (Get-Date).ToString('o')
            Branch = $Branch
            ModuleSubPath = $ModuleSubPath
            LatestVersionPath = $latestVersionPath
        }

        $metadataFile = Join-Path $metadataDir "$ModuleName.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile
        
        Write-Verbose "Saved metadata for module: $ModuleName"
    }
    catch {
        Write-Warning "Failed to save metadata for module '$ModuleName': $($_.Exception.Message)"
    }
}
