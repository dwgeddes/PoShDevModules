<#
.SYNOPSIS
    Executes a script block with progress preference suppressed

.DESCRIPTION
    Internal helper function that temporarily suppresses PowerShell progress bars
    during operations that might hang in non-interactive environments.

.PARAMETER ScriptBlock
    The script block to execute with progress suppressed

.EXAMPLE
    Invoke-WithProgressSuppressed { 
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force 
    }

.NOTES
    This function consolidates the progress suppression pattern used across
    GitHub operations and other functions that might display progress bars.
#>
function Invoke-WithProgressSuppressed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )
    
    # Store current preference
    $oldProgressPreference = $ProgressPreference
    
    try {
        # Suppress progress to prevent hanging in non-interactive environments
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Executing operation with progress suppressed"
        
        # Execute the script block
        & $ScriptBlock
    }
    finally {
        # Restore original preference
        $ProgressPreference = $oldProgressPreference
    }
}
