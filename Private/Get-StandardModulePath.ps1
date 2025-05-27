<#
.SYNOPSIS
    Gets the standard PowerShell module path for the current user

.DESCRIPTION
    Returns the standard PowerShell module path where modules should be installed
    for automatic discovery by PowerShell

.PARAMETER Scope
    Installation scope: CurrentUser (default) or AllUsers

.EXAMPLE
    Get-StandardModulePath
    
.EXAMPLE
    Get-StandardModulePath -Scope AllUsers
#>
function Get-StandardModulePath {
    [CmdletBinding()]
    param (
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    if ($Scope -eq 'AllUsers') {
        if ($IsWindows) {
            return Join-Path $env:ProgramFiles 'PowerShell\Modules'
        } else {
            return '/usr/local/share/powershell/Modules'
        }
    } else {
        if ($IsWindows) {
            return Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules'
        } else {
            return Join-Path $env:HOME '.local/share/powershell/Modules'
        }
    }
}
