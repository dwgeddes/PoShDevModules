<#
.SYNOPSIS
    Updates a module from a local source

.DESCRIPTION
    Internal function to handle updating modules from local sources

.PARAMETER Module
    Module metadata object
#>
function Update-DevModuleFromLocal {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Module
    )

    try {
        Write-Verbose "Updating module '$($Module.Name)' from local source: $($Module.SourcePath)"

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
        $newVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
        
        Write-Verbose "Found module manifest: $($manifestFile.Name)"
        Write-Verbose "Updating to version: $newVersion"

        # Extract install base path from Module.InstallPath 
        # Module.InstallPath should point to the version-specific directory
        # e.g., /path/to/Modules/ModuleName/1.0.0
        $versionPath = $Module.InstallPath
        $moduleBasePath = Split-Path $versionPath -Parent  # /path/to/Modules/ModuleName
        $installBasePath = Split-Path $moduleBasePath -Parent  # /path/to/Modules

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
            Write-Verbose "Created new version directory: $newDestinationPath"
        }

        # Copy updated files
        if ($PSCmdlet.ShouldProcess($newDestinationPath, "Copy updated module files")) {
            # Suppress progress to prevent hanging in non-interactive environments
            $ProgressPreference = 'SilentlyContinue'
            Copy-Item -Path (Join-Path $Module.SourcePath '*') -Destination $newDestinationPath -Recurse -Force
            Write-Verbose "Copied updated module files"
        }

        # Update metadata with new version and path
        if ($PSCmdlet.ShouldProcess($Module.Name, "Update module metadata")) {
            Save-ModuleManifest -ModuleName $Module.Name -SourceType 'Local' -SourcePath $Module.SourcePath -InstallPath $installBasePath
        }

        # Reload module if it's currently loaded, but avoid self-reload during pipeline execution
        $currentModule = Get-Module -Name $Module.Name -ErrorAction SilentlyContinue
        if ($currentModule) {
            # Check if we're updating the same module that's currently executing the update
            $isUpdatingSelf = $currentModule.Name -eq 'PoShDevModules' -and $Module.Name -eq 'PoShDevModules'
            
            if (-not $isUpdatingSelf) {
                Remove-Module -Name $Module.Name -Force
                Import-Module $Module.Name -Force
                Write-Verbose "Reloaded module in current session"
            } else {
                Write-Warning "Skipping module reload during self-update to avoid breaking pipeline execution. Please restart PowerShell session to load the updated module."
            }
        }

        Write-Verbose "Successfully updated module '$($Module.Name)' to version '$newVersion' from local source"
        
        # Return the updated module object
        return Get-InstalledDevModule -Name $Module.Name -InstallPath $installBasePath
    }
    catch {
        throw "Failed to update module from local source: $($_.Exception.Message)"
    }
}
