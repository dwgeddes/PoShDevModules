<#
.SYNOPSIS
    Updates an installed development module from its original source

.DESCRIPTION
    This function updates a PowerShell module that was previously installed using
    the development module management system by pulling the latest changes from
    its original source (local path or GitHub repository).

.PARAMETER Name
    Name of the module to update

.PARAMETER PersonalAccessToken
    GitHub Personal Access Token (required if the original source was a private GitHub repository)

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/Documents/PowerShell/DevModules)

.PARAMETER Force
    Skip confirmation prompts and force the update

.PARAMETER LogLevel
    Logging verbosity level: Silent, Normal, or Verbose

.EXAMPLE
    Update-DevModule -Name "MyModule"

.EXAMPLE
    Update-DevModule -Name "MyModule" -PersonalAccessToken "ghp_xxxxxxxxxxxx"

.EXAMPLE
    Update-DevModule -Name "MyModule" -Force -LogLevel Verbose
#>
function Update-DevModule {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Alias('PAT', 'GitHubToken')]
        [string]$PersonalAccessToken,
        
        [string]$InstallPath,
        
        [switch]$Force,
        
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$LogLevel = 'Normal'
    )

    begin {
        if (-not $InstallPath) {
            $InstallPath = if ($IsWindows) { 
                Join-Path $env:USERPROFILE 'Documents\PowerShell\DevModules' 
            } else { 
                Join-Path $env:HOME 'Documents/PowerShell/DevModules' 
            }
        }
        Write-LogMessage "Starting update of module: $Name" $LogLevel "Normal"
    }

    process {
        try {
            # Get existing module information
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Write-Error "Module '$Name' is not installed. Use Install-DevModule to install it first."
                return
            }

            Write-LogMessage "Found installed module: $($module.Name) (Source: $($module.SourceType))" $LogLevel "Normal"

            # Confirm update unless Force is specified
            if (-not $Force) {
                $title = "Update Development Module"
                $message = "Are you sure you want to update the module '$Name' from '$($module.SourcePath)'?"
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Update the module")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Cancel the operation")
                )
                $decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)
                
                if ($decision -ne 0) {
                    Write-LogMessage "Module update cancelled by user." $LogLevel "Normal"
                    return
                }
            }

            if ($PSCmdlet.ShouldProcess($Name, "Update module")) {
                switch ($module.SourceType) {
                    'Local' {
                        Update-DevModuleFromLocal -Module $module -LogLevel $LogLevel
                    }
                    'GitHub' {
                        $params = @{
                            Module = $module
                            LogLevel = $LogLevel
                        }
                        if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                        
                        Update-DevModuleFromGitHub @params
                    }
                    default {
                        Write-Error "Unknown source type: $($module.SourceType)"
                        return
                    }
                }

                # Update the metadata
                $metadataPath = Join-Path $InstallPath '.metadata'
                $metadataFile = Join-Path $metadataPath "$Name.json"
                
                if (Test-Path $metadataFile) {
                    $metadata = Get-Content $metadataFile | ConvertFrom-Json
                    $metadata.LastUpdated = (Get-Date).ToString('o')
                    $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile
                    Write-LogMessage "Updated metadata for module: $Name" $LogLevel "Verbose"
                }

                Write-LogMessage "Successfully updated module: $Name" $LogLevel "Normal"
            }
        }
        catch {
            Write-Error "Failed to update module '$Name': $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-LogMessage "Module update completed." $LogLevel "Normal"
    }
}
