<#
.SYNOPSIS
    Gets a list of all installed development modules

.DESCRIPTION
    This function retrieves information about all PowerShell modules that have been
    installed using the development module management system.

.PARAMETER Name
    Optional filter to get information about a specific module

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/.local/share/powershell/DevModules on macOS/Linux, ~/Documents/PowerShell/DevModules on Windows)

.EXAMPLE
    Get-InstalledDevModule

.EXAMPLE
    Get-InstalledDevModule -Name "MyModule"

.EXAMPLE
    Get-InstalledDevModule | Format-Table Name, Version, SourceType, InstallDate
#>

function Get-InstalledDevModule {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidateScript({
            if ($_ -and -not (Test-Path $_ -PathType Container)) {
                # Allow non-existent paths - they'll be handled gracefully in the function
                return $true
            }
            $true
        })]
        [string]$InstallPath
    )

    begin {
        if (-not $InstallPath) {
            $InstallPath = Get-DevModulesPath
        }
        
        # Robust cross-platform path normalization
        $InstallPath = $InstallPath -replace '\\', [System.IO.Path]::DirectorySeparatorChar
        
        # Handle edge case where backslash replacement creates invalid UNC-style paths on Unix
        if ((-not $IsWindows -or $PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -ne 'Windows_NT') -and $InstallPath.StartsWith('\\')) {
            # On Unix systems, convert leading \\ to / to fix UNC-style artifacts
            $InstallPath = $InstallPath -replace '^\\+', '/'
        }
        
        if (-not (Test-Path $InstallPath)) {
            Write-Verbose "Install path does not exist: $InstallPath"
            return
        }
    }

    process {
        try {
            $metadataPath = Get-ModuleMetadataPath -InstallPath $InstallPath
            if (-not (Test-Path $metadataPath)) {
                Write-Verbose "No metadata found. No modules installed."
                return
            }

            $modules = @()
            $metadataFiles = Get-ChildItem -Path $metadataPath -Filter '*.json' -Force -ErrorAction SilentlyContinue

            foreach ($file in $metadataFiles) {
                try {
                    $metadata = Get-Content $file.FullName -Force | ConvertFrom-Json
                    
                    if ($Name -and $metadata.Name -ne $Name) {
                        continue
                    }
                    
                    $moduleInfo = [PSCustomObject]@{
                        Name = $metadata.Name
                        Version = $metadata.Version
                        SourceType = $metadata.SourceType
                        SourcePath = $metadata.SourcePath
                        InstallPath = $metadata.InstallPath
                        InstallDate = [DateTime]$metadata.InstallDate
                        Branch = $metadata.Branch
                        LastUpdated = if ($metadata.LastUpdated) { [DateTime]$metadata.LastUpdated } else { $null }
                        LatestVersionPath = $metadata.LatestVersionPath
                    }
                    
                    $modules += $moduleInfo
                }
                catch {
                    Write-Warning "Failed to read metadata from $($file.FullName): $($_.Exception.Message)"
                }
            }

            if ($Name -and $modules.Count -eq 0) {
                Write-Warning "Module '$Name' not found in installed development modules."
                return
            }

            return $modules | Sort-Object Name
        }
        catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "get installed modules" -WriteToHost
            return
        }
    }
}
