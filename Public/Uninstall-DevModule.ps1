<#
.SYNOPSIS
    Removes an installed development module

.DESCRIPTION
    This function removes a PowerShell module that was installed using the 
    development module management system.

.PARAMETER Name
    Name of the module to remove

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/.local/share/powershell/DevModules on macOS/Linux, ~/Documents/PowerShell/DevModules on Windows)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    Remove-DevModule -Name "MyModule"

.EXAMPLE
    Remove-DevModule -Name "MyModule" -Force

.EXAMPLE
    Remove-DevModule -Name "MyModule" -Verbose
#>

function Uninstall-DevModule {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidateScript({
            if ($_ -and -not (Test-Path $_ -PathType Container)) {
                # Allow non-existent paths - they'll be handled gracefully in the function
                return $true
            }
            $true
        })]
        [string]$InstallPath,
        
        [switch]$Force
    )

    begin {
        # Validate parameters using standardized validation
        try {
            $validationParams = @{}    
            if ($InstallPath) { 
                $validationParams.InstallPath = $InstallPath 
            }
            Test-StandardParameter @validationParams
        }
        catch {
            # Self-uninstall protection: If we're uninstalling ourselves, use basic error handling  
            if ($Name -eq 'PoShDevModules') {
                Write-Error "Failed to validate remove parameters for '$Name': $($_.Exception.Message)"
                return
            } else {
                Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "validate remove parameters" -WriteToHost
                return
            }
        }
        
        if (-not $InstallPath) {
            $InstallPath = Get-DevModulesPath
        }
        Write-Verbose "Starting removal of module: $Name"
    }

    process {
        try {
            # Check if module exists
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Write-Error "Module '$Name' is not installed."
                return
            }

            # Store module info before removal for return value
            $moduleToRemove = $module.PSObject.Copy()

            $modulePath = $module.InstallPath  # This is now the base module path with all versions
            $metadataPath = Get-ModuleMetadataPath -InstallPath $InstallPath
            $metadataFile = Join-Path $metadataPath "$Name.json"

            # Confirm removal unless Force is specified or in WhatIf mode
            if (-not $Force -and -not $WhatIfPreference) {
                $title = "Remove Development Module"
                $message = "Are you sure you want to remove the module '$Name' from '$modulePath'?"
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Remove the module")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Cancel the operation")
                )
                $decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)
                
                if ($decision -ne 0) {
                    Write-Information "Module removal cancelled by user." -InformationAction Continue
                    return
                }
            }

            # Remove the module if it should be processed
            if ($PSCmdlet.ShouldProcess($modulePath, "Remove module directory")) {
                if (Test-Path $modulePath) {
                    Remove-Item -Path $modulePath -Recurse -Force
                    Write-Verbose "Removed module directory: $modulePath"
                }

                # Remove metadata
                if (Test-Path $metadataFile) {
                    Remove-Item -Path $metadataFile -Force
                    Write-Verbose "Removed module metadata: $metadataFile"
                }

                # Try to remove the module from the current session
                try {
                    if (Get-Module -Name $Name -ErrorAction SilentlyContinue) {
                        # Pipeline protection: Don't remove ourselves from session during pipeline execution
                        # as it breaks subsequent pipeline processing
                        if ($Name -eq 'PoShDevModules') {
                            Write-Warning "Skipping module removal from session during self-uninstall to avoid breaking pipeline execution. Please restart PowerShell session if needed."
                        } else {
                            Remove-Module -Name $Name -Force
                            Write-Verbose "Removed module '$Name' from current session."
                        }
                    }
                }
                catch {
                    Write-Warning "Could not remove module '$Name' from current session: $($_.Exception.Message)"
                }

                Write-Information "Successfully removed module: $Name" -InformationAction Continue
                
                # Return the uninstalled module object
                return $moduleToRemove
            }
        }
        catch {
            # Self-uninstall protection: If we're uninstalling ourselves, use basic error handling
            if ($Name -eq 'PoShDevModules') {
                Write-Error "Failed to remove module '$Name': $($_.Exception.Message)"
                Write-Warning "Module removal may have been partially completed. Check the installation manually."
                return
            } else {
                Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "remove module '$Name'" -WriteToHost
                return
            }
        }
    }

    end {
        Write-Verbose "Module remove completed."
    }
}
