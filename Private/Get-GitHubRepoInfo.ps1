<#
.SYNOPSIS
    Parses GitHub repository information from various input formats

.DESCRIPTION
    Internal function to parse GitHub repository owner and name from different input formats

.PARAMETER GitHubRepo
    GitHub repository in various formats (owner/repo, URL, etc.)

.EXAMPLE
    Get-GitHubRepoInfo -GitHubRepo "microsoft/powershell"

.EXAMPLE
    Get-GitHubRepoInfo -GitHubRepo "https://github.com/microsoft/powershell"
#>
function Get-GitHubRepoInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GitHubRepo
    )

    try {
        # Handle different GitHub repo formats
        if ($GitHubRepo -match '^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$') {
            # Full GitHub URL
            $owner = $matches[1]
            $repo = $matches[2]
        }
        elseif ($GitHubRepo -match '^([^/]+)/([^/]+)$') {
            # Simple owner/repo format
            $owner = $matches[1]
            $repo = $matches[2]
        }
        else {
            throw "Invalid GitHub repository format. Expected 'owner/repo' or full GitHub URL."
        }

        return [PSCustomObject]@{
            Owner = $owner
            Repo = $repo
            FullName = "$owner/$repo"
        }
    }
    catch {
        throw "Failed to parse GitHub repository information: $($_.Exception.Message)"
    }
}
