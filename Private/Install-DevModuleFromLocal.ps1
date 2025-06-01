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
        
        # Validate manifest before installation
        try {
            $moduleVersion = Get-ModuleVersionFromManifest -ManifestPath $manifestFile.FullName
            # Additional validation: Test if manifest can be properly parsed
            $testManifest = Import-PowerShellDataFile -Path $manifestFile.FullName -ErrorAction Stop
            if (-not $testManifest) {
                throw "Invalid module manifest: Cannot parse as PowerShell data file"
            }
        }
        catch {
            throw "Failed to validate module manifest: $($_.Exception.Message)"
        }
        
        Write-Verbose "Found module manifest: $($manifestFile.Name)"
        Write-Verbose "Module name: $moduleName, Version: $moduleVersion"

        # Create version-specific destination path and handle existing installations
        $pathInfo = New-ModuleInstallPath -InstallPath $InstallPath -ModuleName $moduleName -ModuleVersion $moduleVersion -Force:$Force
        $destinationPath = $pathInfo.DestinationPath

        # Prepare destination directory
        Initialize-ModuleDestination -DestinationPath $destinationPath -Force:$Force -PSCmdlet $PSCmdlet

        # Copy module files
        # Suppress progress to prevent hanging in non-interactive environments
        Invoke-WithProgressSuppressed {
            Copy-Item -Path (Join-Path $SourcePath '*') -Destination $destinationPath -Recurse -Force
        }
        Write-Verbose "Copied module files from $SourcePath to $destinationPath"

        # Save metadata
        Save-ModuleManifest -ModuleName $moduleName -SourceType 'Local' -SourcePath $SourcePath -InstallPath $InstallPath

        # Import module if requested
        if (-not $SkipImport) {
            try {
                $installedManifestPath = Join-Path $destinationPath "$moduleName.psd1"
                Import-Module $installedManifestPath -Force
                Write-Information "Imported module: $moduleName" -InformationAction Continue
            }
            catch {
                Write-Warning "Module installed but failed to import: $($_.Exception.Message)"
            }
        }

        Write-Information "Successfully installed module '$moduleName' from local path" -InformationAction Continue
        
        # Return the installed module object with status
        $installedModule = Get-InstalledDevModule -Name $moduleName -InstallPath $InstallPath
        $installedModule | Add-Member -MemberType NoteProperty -Name 'Status' -Value 'Success' -Force
        return $installedModule
    }
    catch {
        throw "Failed to install module from local path: $($_.Exception.Message)"
    }
}
