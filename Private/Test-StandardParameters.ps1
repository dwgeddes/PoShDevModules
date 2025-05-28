<#
.SYNOPSIS
    Provides standardized parameter validation for the module

.DESCRIPTION
    Internal function that provides consistent parameter validation patterns
    across all module functions, with clear error messages and proper handling.

.PARAMETER GitHubRepo
    GitHub repository to validate (if provided)

.PARAMETER SourcePath
    Local source path to validate (if provided)

.PARAMETER ModuleName
    Module name to validate (if provided)

.PARAMETER InstallPath
    Installation path to validate (if provided)

.EXAMPLE
    Test-StandardParameter -GitHubRepo "user/repo" -InstallPath "/some/path"
#>
function Test-StandardParameter {
    [CmdletBinding()]
    param(
        [string]$GitHubRepo,
        [string]$SourcePath,
        [string]$ModuleName,
        [string]$InstallPath
    )
    
    # Improved parameter validation
    if ($GitHubRepo) {
        if (-not ($GitHubRepo -match '^([^/]+)/([^/]+)$|^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$')) {
            throw [System.ArgumentException]::new("Invalid GitHub repository format. Expected 'owner/repo' or full GitHub URL.")
        }
    }

    if ($SourcePath) {
        if (-not (Test-Path $SourcePath -PathType Container)) {
            throw [System.ArgumentException]::new("Source path does not exist or is not a directory: $SourcePath")
        }
    }

    if ($ModuleName) {
        if (-not ($ModuleName -match '^[a-zA-Z][a-zA-Z0-9._-]*$')) {
            throw [System.ArgumentException]::new("Invalid module name format. Module names must start with a letter and contain only letters, numbers, dots, hyphens, and underscores.")
        }
    }

    if ($InstallPath) {
        $parentPath = Split-Path $InstallPath -Parent
        if ($parentPath -and -not (Test-Path $parentPath -PathType Container)) {
            throw [System.ArgumentException]::new("Parent directory of install path does not exist: $parentPath")
        }
    }
}
