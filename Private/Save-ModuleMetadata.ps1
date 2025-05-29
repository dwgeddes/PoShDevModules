<#
.SYNOPSIS
    Saves metadata about an insta    try {
        # Ensure metadata directory exists
        $metadataPath = Get-ModuleMetadataPath -InstallPath $InstallPath
        if (-not (Test-Path $metadataPath)) {
            New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created metadata directory: $metadataPath"
        }dule

.DESCRIPTION
    Internal function to save metadata about an installed module for tracking and update purposes

.PARAMETER ModuleName
    The name of the module

.PARAMETER SourceType
    The source type (Local or GitHub)

.PARAMETER SourcePath
    The path to the source (local path or GitHub repo)

.PARAMETER InstallPath
    The path where the module is installed

.PARAMETER Branch
    The GitHub branch (if applicable)

.PARAMETER ModuleSubPath
    The module subdirectory within the repository (if applicable)
#>
function Save-ModuleManifest {
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
        # Ensure metadata directory exists
        $metadataPath = Join-Path $InstallPath '.metadata'
        if (-not (Test-Path $metadataPath)) {
            New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created metadata directory: $metadataPath"
        }

        # Determine version from installed module manifest
        $moduleVersionPath = $null
        $moduleBasePath = Join-Path $InstallPath $ModuleName
        
        if (Test-Path $moduleBasePath) {
            # Look for subdirectories (version directories)
            $versionDirs = Get-ChildItem -Path $moduleBasePath -Directory | Sort-Object Name -Descending
            
            if ($versionDirs.Count -gt 0) {
                $latestVersion = $versionDirs[0].Name
                $moduleVersionPath = $versionDirs[0].FullName
                
                # Try to get version from manifest (more reliable)
                $manifestPath = Join-Path $moduleVersionPath "$ModuleName.psd1"
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Import-PowerShellDataFile -Path $manifestPath
                        if ($manifest.ModuleVersion) {
                            $latestVersion = $manifest.ModuleVersion
                        }
                    }
                    catch {
                        Write-Verbose "Could not read module manifest: $($_.Exception.Message)"
                    }
                }
            }
            else {
                # No version subdirectories, assume flat structure
                $moduleVersionPath = $moduleBasePath
                $manifestPath = Join-Path $moduleVersionPath "$ModuleName.psd1"
                
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Import-PowerShellDataFile -Path $manifestPath
                        if ($manifest.ModuleVersion) {
                            $latestVersion = $manifest.ModuleVersion
                        }
                        else {
                            $latestVersion = "0.0.0"
                        }
                    }
                    catch {
                        Write-Verbose "Could not read module manifest: $($_.Exception.Message)"
                        $latestVersion = "0.0.0"
                    }
                }
                else {
                    $latestVersion = "0.0.0"
                }
            }
        }
        else {
            Write-Warning "Module directory not found: $moduleBasePath"
            $latestVersion = "0.0.0"
        }

        # Create metadata object
        $metadata = [PSCustomObject]@{
            Name = $ModuleName
            Version = $latestVersion
            SourceType = $SourceType
            SourcePath = $SourcePath
            InstallPath = $moduleVersionPath  # Store the path to the specific version directory
            InstallDate = (Get-Date).ToString('o')
            Branch = $Branch
            ModuleSubPath = $ModuleSubPath
            LastUpdated = $null
            LatestVersionPath = $moduleVersionPath
        }

        # Save metadata
        $metadataFile = Join-Path $metadataPath "$ModuleName.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Force

        Write-Verbose "Saved module metadata to: $metadataFile"
    }
    catch {
        Write-Warning "Failed to save metadata for module '$ModuleName': $($_.Exception.Message)"
    }
}
