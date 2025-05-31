<#
.SYNOPSIS
    Creates a temporary directory with automatic cleanup capability

.DESCRIPTION
    Internal helper function that creates a uniquely named temporary directory
    for module operations. Returns a hashtable with the path and cleanup scriptblock.

.EXAMPLE
    $tempInfo = New-TempDirectory
    try {
        # Use $tempInfo.Path for operations
    } finally {
        & $tempInfo.Cleanup
    }

.NOTES
    This function consolidates the temporary directory creation pattern used
    across GitHub install and update operations.
#>
function New-TempDirectory {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Prefix = "DevModule"
    )
    
    # Create unique temporary directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "${Prefix}_$(Get-Random)"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    Write-Verbose "Created temporary directory: $tempDir"
    
    # Return path and cleanup scriptblock
    return @{
        Path = $tempDir
        Cleanup = {
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Cleaned up temporary directory: $tempDir"
            }
        }.GetNewClosure()
    }
}
