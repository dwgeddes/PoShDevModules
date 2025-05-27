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

.PARAMETER LogLevel
    Logging level
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
        [string]$ModuleSubPath,
        [string]$LogLevel
    )

    try {
        $metadataDir = Join-Path $InstallPath '.metadata'
        if (-not (Test-Path $metadataDir)) {
            New-Item -Path $metadataDir -ItemType Directory -Force | Out-Null
            Write-LogMessage "Created metadata directory: $metadataDir" $LogLevel "Verbose"
        }

        # Try to get module version from manifest
        $moduleDir = Join-Path $InstallPath $ModuleName
        $manifestPath = Join-Path $moduleDir "$ModuleName.psd1"
        $version = "Unknown"
        
        if (Test-Path $manifestPath) {
            try {
                $manifest = Import-PowerShellDataFile $manifestPath
                $version = $manifest.ModuleVersion
            }
            catch {
                Write-LogMessage "Could not read version from manifest: $($_.Exception.Message)" $LogLevel "Verbose"
            }
        }

        $metadata = @{
            Name = $ModuleName
            Version = $version
            SourceType = $SourceType
            SourcePath = $SourcePath
            InstallPath = $moduleDir
            InstallDate = (Get-Date).ToString('o')
            Branch = $Branch
            ModuleSubPath = $ModuleSubPath
        }

        $metadataFile = Join-Path $metadataDir "$ModuleName.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile
        
        Write-LogMessage "Saved metadata for module: $ModuleName" $LogLevel "Verbose"
    }
    catch {
        Write-Warning "Failed to save metadata for module '$ModuleName': $($_.Exception.Message)"
    }
}
