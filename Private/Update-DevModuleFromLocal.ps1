<#
.SYNOPSIS
    Updates a module from a local source

.DESCRIPTION
    Internal function to handle updating modules from local sources

.PARAMETER Module
    Module metadata object
#>
function Update-DevModuleFromLocal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Module
    )

    try {
        Write-Host "Updating module '$($Module.Name)' from local source: $($Module.SourcePath)" -ForegroundColor Green

        # Validate source still exists
        if (-not (Test-Path $Module.SourcePath -PathType Container)) {
            throw "Source path no longer exists: $($Module.SourcePath)"
        }

        # Find and validate module manifest in source
        $manifestFiles = Get-ChildItem -Path $Module.SourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
        if ($manifestFiles.Count -eq 0) {
            throw "No PowerShell module manifest (.psd1) found in source: $($Module.SourcePath)"
        }

        $manifestFile = $manifestFiles[0]
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestFile.Name)
        $newVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
        
        Write-Verbose "Found module manifest: $($manifestFile.Name)"
        Write-Host "Updating to version: $newVersion" -ForegroundColor Green

        # Extract install base path from Module.InstallPath (remove old version directory if present)
        $installBasePath = Split-Path $Module.InstallPath -Parent
        if ((Split-Path $installBasePath -Leaf) -eq $Module.Name) {
            # Module.InstallPath was already the base path
            $moduleBasePath = $Module.InstallPath
            $installBasePath = Split-Path $moduleBasePath -Parent
        } else {
            # Module.InstallPath included version directory
            $moduleBasePath = Join-Path $installBasePath $Module.Name
        }

        # Create new version-specific destination path
        $newDestinationPath = Join-Path $moduleBasePath $newVersion

        # Remove existing version directory if it exists
        if (Test-Path $newDestinationPath) {
            Remove-Item -Path $newDestinationPath -Recurse -Force
            Write-Verbose "Removed existing version directory: $newDestinationPath"
        }

        # Create new version directory
        New-Item -Path $newDestinationPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created new version directory: $newDestinationPath"

        # Copy updated files
        Copy-Item -Path "$($Module.SourcePath)\*" -Destination $newDestinationPath -Recurse -Force
        Write-Host "Copied updated module files" -ForegroundColor Green

        # Update metadata with new version and path
        Save-ModuleMetadata -ModuleName $Module.Name -SourceType 'Local' -SourcePath $Module.SourcePath -InstallPath $installBasePath

        # Reload module if it's currently loaded
        if (Get-Module -Name $Module.Name -ErrorAction SilentlyContinue) {
            Remove-Module -Name $Module.Name -Force
            Import-Module $Module.Name -Force
            Write-Host "Reloaded module in current session" -ForegroundColor Green
        }

        Write-Host "Successfully updated module '$($Module.Name)' to version '$newVersion' from local source" -ForegroundColor Green
        
        # Return the updated module object
        return Get-InstalledDevModule -Name $Module.Name -InstallPath $installBasePath
    }
    catch {
        throw "Failed to update module from local source: $($_.Exception.Message)"
    }
}
