<#
.SYNOPSIS
    Removes an installed development module

.DESCRIPTION
    This function removes a PowerShell module that was installed using the 
    development module management system.

.PARAMETER Name
    Name of the module to remove

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/Documents/PowerShell/DevModules)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER LogLevel
    Logging verbosity level: Silent, Normal, or Verbose

.EXAMPLE
    Remove-DevModule -Name "MyModule"

.EXAMPLE
    Remove-DevModule -Name "MyModule" -Force

.EXAMPLE
    Remove-DevModule -Name "MyModule" -LogLevel Verbose
#>
function Remove-DevModule {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
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
        Write-LogMessage "Starting removal of module: $Name" $LogLevel "Normal"
    }

    process {
        try {
            # Check if module exists
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Write-Error "Module '$Name' is not installed."
                return
            }

            $modulePath = Join-Path $InstallPath $Name
            $metadataPath = Join-Path $InstallPath '.metadata'
            $metadataFile = Join-Path $metadataPath "$Name.json"

            # Confirm removal unless Force is specified
            if (-not $Force) {
                $title = "Remove Development Module"
                $message = "Are you sure you want to remove the module '$Name' from '$modulePath'?"
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Remove the module")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Cancel the operation")
                )
                $decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)
                
                if ($decision -ne 0) {
                    Write-LogMessage "Module removal cancelled by user." $LogLevel "Normal"
                    return
                }
            }

            # Remove the module if it should be processed
            if ($PSCmdlet.ShouldProcess($modulePath, "Remove module directory")) {
                if (Test-Path $modulePath) {
                    Remove-Item -Path $modulePath -Recurse -Force
                    Write-LogMessage "Removed module directory: $modulePath" $LogLevel "Normal"
                }

                # Remove metadata
                if (Test-Path $metadataFile) {
                    Remove-Item -Path $metadataFile -Force
                    Write-LogMessage "Removed module metadata: $metadataFile" $LogLevel "Verbose"
                }

                # Try to remove the module from the current session
                try {
                    if (Get-Module -Name $Name -ErrorAction SilentlyContinue) {
                        Remove-Module -Name $Name -Force
                        Write-LogMessage "Removed module '$Name' from current session." $LogLevel "Normal"
                    }
                }
                catch {
                    Write-Warning "Could not remove module '$Name' from current session: $($_.Exception.Message)"
                }

                Write-LogMessage "Successfully removed module: $Name" $LogLevel "Normal"
            }
        }
        catch {
            Write-Error "Failed to remove module '$Name': $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-LogMessage "Module removal completed." $LogLevel "Normal"
    }
}
