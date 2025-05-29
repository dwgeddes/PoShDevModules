<#
.SYNOPSIS
    Adds a custom path to the PowerShell module path

.DESCRIPTION
    Ensures a custom directory is included in the PSModulePath environment variable
    for module auto-discovery

.PARAMETER Path
    The path to add to PSModulePath

.PARAMETER Persistent
    Whether to make the change persistent across sessions

.EXAMPLE
    Add-ToModulePath -Path "/custom/modules"
    
.EXAMPLE
    Add-ToModulePath -Path "/custom/modules" -Persistent
#>
function Add-ToModulePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Persistent
    )

    # Normalize the path
    $normalizedPath = $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    
    # Get current PSModulePath
    $currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    
    # Check if path is already included
    if ($currentPaths -notcontains $normalizedPath) {
        # Add to current session
        $env:PSModulePath = "$normalizedPath$([System.IO.Path]::PathSeparator)$env:PSModulePath"
        
        if ($Persistent) {
            # Make persistent across sessions
            if ($IsWindows) {
                # Windows - use registry
                $currentRegValue = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
                if (-not $currentRegValue -or $currentRegValue -notlike "*$normalizedPath*") {
                    $newValue = if ($currentRegValue) { 
                        "$normalizedPath$([System.IO.Path]::PathSeparator)$currentRegValue"
                    } else {
                        $normalizedPath
                    }
                    [Environment]::SetEnvironmentVariable('PSModulePath', $newValue, 'User')
                }
            } else {
                # macOS/Linux - add to profile
                $profilePath = $PROFILE.CurrentUserAllHosts
                $profileDir = Split-Path $profilePath -Parent
                
                if (-not (Test-Path $profileDir)) {
                    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
                }
                
                $exportLine = "`$env:PSModulePath = `"$normalizedPath`$([System.IO.Path]::PathSeparator)`$env:PSModulePath`""
                
                if (Test-Path $profilePath) {
                    $profileContent = Get-Content $profilePath -Raw
                    if ($profileContent -notlike "*$normalizedPath*") {
                        Add-Content -Path $profilePath -Value $exportLine
                    }
                } else {
                    Set-Content -Path $profilePath -Value $exportLine
                }
            }
        }
        
        Write-Verbose "Added '$normalizedPath' to PSModulePath"
    } else {
        Write-Verbose "Path '$normalizedPath' already in PSModulePath"
    }
}
