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
    Path where development modules are installed (default: ~/.local/share/powershell/DevModules on macOS/Linux, ~/Documents/PowerShell/DevModules on Windows)

.PARAMETER Force
    Skip confirmation prompts and force the update

.EXAMPLE
    Update-DevModule -Name "MyModule"

.EXAMPLE
    Update-DevModule -Name "MyModule" -PersonalAccessToken "ghp_xxxxxxxxxxxx"

.EXAMPLE
    Update-DevModule -Name "MyModule" -Force -Verbose
#>
function Update-DevModule {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Alias('PAT', 'GitHubToken')]
        [ValidateNotNullOrEmpty()]
        [string]$PersonalAccessToken,
        
        [string]$InstallPath,
        
        [switch]$Force
    )

    begin {
        if (-not $InstallPath) {
            $InstallPath = Get-DevModulesPath
        }
        Write-Verbose "Starting update of module: $Name"
    }

    process {
        try {
            # Get existing module information
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Invoke-StandardErrorHandling -ErrorRecord (New-Object System.Management.Automation.ErrorRecord(
                    (New-Object System.InvalidOperationException("Module '$Name' is not installed. Use Install-DevModule to install it first.")),
                    "ModuleNotInstalled",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Name
                )) -Operation "find installed module" -WriteToHost -NonTerminating
                return
            }

            Write-Verbose "Found installed module: $($module.Name) (Source: $($module.SourceType))"

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
                    Write-Host "Module update cancelled by user." -ForegroundColor Yellow
                    return
                }
            }

            if ($PSCmdlet.ShouldProcess($Name, "Update module")) {
                $updatedModule = switch ($module.SourceType) {
                    'Local' {
                        Update-DevModuleFromLocal -Module $module
                    }
                    'GitHub' {
                        $params = @{
                            Module = $module
                        }
                        if ($PersonalAccessToken) { $params.PersonalAccessToken = $PersonalAccessToken }
                        
                        Update-DevModuleFromGitHub @params
                    }
                    default {
                        Invoke-StandardErrorHandling -ErrorRecord (New-Object System.Management.Automation.ErrorRecord(
                            (New-Object System.InvalidOperationException("Unknown source type: $($module.SourceType)")),
                            "UnknownSourceType",
                            [System.Management.Automation.ErrorCategory]::InvalidData,
                            $module.SourceType
                        )) -Operation "determine module source type" -WriteToHost
                        return
                    }
                }

                # Update the metadata LastUpdated timestamp
                $metadataPath = Join-Path $InstallPath '.metadata'
                $metadataFile = Join-Path $metadataPath "$Name.json"
                
                if (Test-Path $metadataFile) {
                    $metadata = Get-Content $metadataFile | ConvertFrom-Json
                    # Add LastUpdated property if it doesn't exist
                    if (-not $metadata.PSObject.Properties['LastUpdated']) {
                        $metadata | Add-Member -MemberType NoteProperty -Name 'LastUpdated' -Value $null
                    }
                    $metadata.LastUpdated = (Get-Date).ToString('o')
                    $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile
                    Write-Verbose "Updated metadata timestamp for module: $Name"
                }

                Write-Host "Successfully updated module: $Name" -ForegroundColor Green
                
                # Return the updated module object
                return $updatedModule
            }
        }
        catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "update module '$Name'" -WriteToHost
            return
        }
    }

    end {
        Write-Verbose "Module update completed."
    }
}
