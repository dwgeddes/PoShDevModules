<#
.SYNOPSIS
    Installs a module from a local filesystem path

.DESCRIPTION
    Internal function to handle installation from local sources

.PARAMETER SourcePath
    Path to the local module directory

.PARAMETER InstallPath
    Where to install the module

.PARAMETER Force
    Whether to force overwrite existing modules

.PARAMETER SkipImport
    Whether to skip importing after installation

.PARAMETER LogLevel
    Logging level
#>
function Install-DevModuleFromLocal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        
        [switch]$Force,
        [switch]$SkipImport,
        [string]$LogLevel
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
        
        Write-LogMessage "Found module manifest: $($manifestFile.Name)" $LogLevel "Verbose"
        Write-LogMessage "Module name: $moduleName" $LogLevel "Normal"

        $destinationPath = Join-Path $InstallPath $moduleName

        # Check if module already exists
        if ((Test-Path $destinationPath) -and -not $Force) {
            throw "Module '$moduleName' already exists at $destinationPath. Use -Force to overwrite."
        }

        # Create destination directory
        if (Test-Path $destinationPath) {
            Remove-Item -Path $destinationPath -Recurse -Force
            Write-LogMessage "Removed existing module directory" $LogLevel "Verbose"
        }

        New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
        Write-LogMessage "Created destination directory: $destinationPath" $LogLevel "Verbose"

        # Copy module files
        Copy-Item -Path "$SourcePath\*" -Destination $destinationPath -Recurse -Force
        Write-LogMessage "Copied module files from $SourcePath to $destinationPath" $LogLevel "Normal"

        # Save metadata
        Save-ModuleMetadata -ModuleName $moduleName -SourceType 'Local' -SourcePath $SourcePath -InstallPath $InstallPath -LogLevel $LogLevel

        # Import module if requested
        if (-not $SkipImport) {
            try {
                Import-Module $destinationPath -Force
                Write-LogMessage "Imported module: $moduleName" $LogLevel "Normal"
            }
            catch {
                Write-Warning "Module installed but failed to import: $($_.Exception.Message)"
            }
        }

        Write-LogMessage "Successfully installed module '$moduleName' from local path" $LogLevel "Normal"
    }
    catch {
        throw "Failed to install module from local path: $($_.Exception.Message)"
    }
}
