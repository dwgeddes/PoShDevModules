<#
.SYNOPSIS
    Gets a list of all installed development modules

.DESCRIPTION
    This function retrieves information about all PowerShell modules that have been
    installed using the development module management system.

.PARAMETER Name
    Optional filter to get information about a specific module

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/Documents/PowerShell/DevModules)

.EXAMPLE
    Get-InstalledDevModule

.EXAMPLE
    Get-InstalledDevModule -Name "MyModule"

.EXAMPLE
    Get-InstalledDevModule | Format-Table Name, Version, SourceType, InstallDate
#>
function Get-InstalledDevModule {
    [CmdletBinding()]
    param (
        [string]$Name,
        [string]$InstallPath
    )

    begin {
        if (-not $InstallPath) {
            $InstallPath = if ($IsWindows) { 
                Join-Path $env:USERPROFILE 'Documents\PowerShell\DevModules' 
            } else { 
                Join-Path $env:HOME 'Documents/PowerShell/DevModules' 
            }
        }
        if (-not (Test-Path $InstallPath)) {
            Write-Verbose "Install path does not exist: $InstallPath"
            return
        }
    }

    process {
        try {
            $metadataPath = Join-Path $InstallPath '.metadata'
            if (-not (Test-Path $metadataPath)) {
                Write-Verbose "No metadata found. No modules installed."
                return
            }

            $modules = @()
            $metadataFiles = Get-ChildItem -Path $metadataPath -Filter '*.json' -ErrorAction SilentlyContinue

            foreach ($file in $metadataFiles) {
                try {
                    $metadata = Get-Content $file.FullName | ConvertFrom-Json
                    
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
            Write-Error "Failed to get installed modules: $($_.Exception.Message)"
            throw
        }
    }
}
