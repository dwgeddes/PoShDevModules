<#
.SYNOPSIS
    Updates a module from a local source

.DESCRIPTION
    Internal function to handle updating modules from local sources

.PARAMETER Module
    Module metadata object

.PARAMETER LogLevel
    Logging level
#>
function Update-DevModuleFromLocal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Module,
        
        [string]$LogLevel
    )

    try {
        Write-LogMessage "Updating module '$($Module.Name)' from local source: $($Module.SourcePath)" $LogLevel "Normal"

        # Validate source still exists
        if (-not (Test-Path $Module.SourcePath -PathType Container)) {
            throw "Source path no longer exists: $($Module.SourcePath)"
        }

        # Remove existing module directory
        if (Test-Path $Module.InstallPath) {
            Remove-Item -Path $Module.InstallPath -Recurse -Force
            Write-LogMessage "Removed existing module directory" $LogLevel "Verbose"
        }

        # Create new directory
        New-Item -Path $Module.InstallPath -ItemType Directory -Force | Out-Null

        # Copy updated files
        Copy-Item -Path "$($Module.SourcePath)\*" -Destination $Module.InstallPath -Recurse -Force
        Write-LogMessage "Copied updated module files" $LogLevel "Normal"

        # Reload module if it's currently loaded
        if (Get-Module -Name $Module.Name -ErrorAction SilentlyContinue) {
            Remove-Module -Name $Module.Name -Force
            Import-Module $Module.InstallPath -Force
            Write-LogMessage "Reloaded module in current session" $LogLevel "Normal"
        }

        Write-LogMessage "Successfully updated module '$($Module.Name)' from local source" $LogLevel "Normal"
    }
    catch {
        throw "Failed to update module from local source: $($_.Exception.Message)"
    }
}
