<#
.SYNOPSIS
    Installs a module from a local filesystem path

.DESCRIPTION
    Internal helper function to handle installation from local sources

.PARAMETER SourcePath
    Path to the local module directory

.PARAMETER InstallPath
    Where to install the module

.PARAMETER Force
    Whether to force overwrite existing modules

.PARAMETER SkipImport
    Whether to skip importing after installation
#>
function Install-DevModuleFromLocal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        
        [switch]$Force,
        [switch]$SkipImport
    )

    try {
        # Validate source path
        if (-not (Test-Path $SourcePath -PathType Container)) {
            throw "Source path does not exist or is not a directory: $SourcePath"
        }

        # Try to find a module manifest to get the module name
        $manifestFiles = Get-ChildItem -Path $SourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
        if ($manifestFiles.Count -eq 0) {
            throw "No PowerShell module manifest (.psd1) found in source path: $SourcePath"
        }

        $manifestFile = $manifestFiles[0]
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestFile.Name)
        $moduleVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
        
        Write-Verbose "Found module manifest: $($manifestFile.Name)"
        Write-Host "Module name: $moduleName, Version: $moduleVersion" -ForegroundColor Green

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
        Write-Verbose "Created destination directory: $destinationPath"

        # Copy module files
        Copy-Item -Path "$SourcePath\*" -Destination $destinationPath -Recurse -Force
        Write-Host "Copied module files from $SourcePath to $destinationPath" -ForegroundColor Green

        # Save metadata
        Save-ModuleMetadata -ModuleName $moduleName -SourceType 'Local' -SourcePath $SourcePath -InstallPath $InstallPath

        # Import module if requested
        if (-not $SkipImport) {
            try {
                Import-Module $moduleName -Force
                Write-Host "Imported module: $moduleName" -ForegroundColor Green
            }
            catch {
                Write-Warning "Module installed but failed to import: $($_.Exception.Message)"
            }
        }

        Write-Host "Successfully installed module '$moduleName' from local path" -ForegroundColor Green
        
        # Return the installed module object
        return Get-InstalledDevModule -Name $moduleName -InstallPath $InstallPath
    }
    catch {
        throw "Failed to install module from local path: $($_.Exception.Message)"
    }
}
