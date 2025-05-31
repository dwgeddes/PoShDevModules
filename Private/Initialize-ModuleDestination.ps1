<#
.SYNOPSIS
    Prepares destination directory for module installation

.DESCRIPTION
    Internal helper function that handles the common pattern of preparing
    a destination directory for module installation, including removal of
    existing versions when Force is specified.

.PARAMETER DestinationPath
    The destination path where the module will be installed

.PARAMETER Force
    Whether to remove existing installations

.PARAMETER PSCmdlet
    The PSCmdlet object for ShouldProcess support

.EXAMPLE
    Initialize-ModuleDestination -DestinationPath $destinationPath -Force:$Force -PSCmdlet $PSCmdlet

.NOTES
    This function consolidates the destination preparation pattern used across
    install and update functions.
#>
function Initialize-ModuleDestination {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        
        [switch]$Force,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$PSCmdlet
    )
    
    # Remove existing version directory if it exists and Force is specified
    if ((Test-Path $DestinationPath) -and $Force) {
        if ($PSCmdlet.ShouldProcess($DestinationPath, "Remove existing module directory")) {
            Remove-Item -Path $DestinationPath -Recurse -Force
            Write-Verbose "Removed existing module directory: $DestinationPath"
        }
    }
    
    # Create destination directory
    if ($PSCmdlet.ShouldProcess($DestinationPath, "Create module directory")) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created destination directory: $DestinationPath"
    }
}
