<#
.SYNOPSIS
    Extracts module version from a PowerShell module manifest

.DESCRIPTION
    Safely extracts the module version from a .psd1 manifest file

.PARAMETER ManifestPath
    Path to the PowerShell module manifest (.psd1) file

.EXAMPLE
    Get-ModuleVersionFromManifest -ManifestPath "/path/to/Module.psd1"
#>
function Get-ModuleVersionFromManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    try {
        if (-not (Test-Path $ManifestPath)) {
            throw "Manifest file not found: $ManifestPath"
        }

        $manifest = Import-PowerShellDataFile -Path $ManifestPath
        
        if (-not $manifest.ModuleVersion) {
            Write-Warning "No ModuleVersion found in manifest, using default version 1.0.0"
            return "1.0.0"
        }

        return $manifest.ModuleVersion.ToString()
    }
    catch {
        Write-Warning "Failed to read module version from manifest: $($_.Exception.Message). Using default version 1.0.0"
        return "1.0.0"
    }
}
