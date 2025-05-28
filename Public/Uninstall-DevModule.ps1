<#
.SYNOPSIS
    Uninstalls an installed development module

.DESCRIPTION
    This function uninstalls a PowerShell module that was installed using the 
    development module management system.

.PARAMETER Name
    Name of the module to uninstall

.PARAMETER InstallPath
    Path where development modules are installed (default: ~/.local/share/powershell/DevModules on macOS/Linux, ~/Documents/PowerShell/DevModules on Windows)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    Uninstall-DevModule -Name "MyModule"

.EXAMPLE
    Uninstall-DevModule -Name "MyModule" -Force

.EXAMPLE
    Uninstall-DevModule -Name "MyModule" -Verbose
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
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "validate uninstall parameters" -WriteToHost
            return
        }
        
        if (-not $InstallPath) {
            $InstallPath = Get-DevModulesPath
        }
        Write-Verbose "Starting uninstall of module: $Name"
    }

    process {
        try {
            # Check if module exists
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Invoke-StandardErrorHandling -ErrorRecord (New-Object System.Management.Automation.ErrorRecord(
                    (New-Object System.InvalidOperationException("Module '$Name' is not installed.")),
                    "ModuleNotInstalled",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Name
                )) -Operation "find installed module" -WriteToHost -NonTerminating
                return
            }

            # Store module info before removal for return value
            $moduleToRemove = $module.PSObject.Copy()

            $modulePath = $module.InstallPath  # This is now the base module path with all versions
            $metadataPath = Get-ModuleMetadataPath -InstallPath $InstallPath
            $metadataFile = Join-Path $metadataPath "$Name.json"

            # Confirm removal unless Force is specified or in WhatIf mode
            if (-not $Force -and -not $WhatIfPreference) {
                $title = "Uninstall Development Module"
                $message = "Are you sure you want to uninstall the module '$Name' from '$modulePath'?"
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Uninstall the module")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Cancel the operation")
                )
                $decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)
                
                if ($decision -ne 0) {
                    Write-Host "Module uninstall cancelled by user." -ForegroundColor Yellow
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
                        Remove-Module -Name $Name -Force
                        Write-Verbose "Removed module '$Name' from current session."
                    }
                }
                catch {
                    Write-Warning "Could not remove module '$Name' from current session: $($_.Exception.Message)"
                }

                Write-Host "Successfully uninstalled module: $Name" -ForegroundColor Green
                
                # Return the uninstalled module object
                return $moduleToRemove
            }
        }
        catch {
            Invoke-StandardErrorHandling -ErrorRecord $_ -Operation "remove module '$Name'" -WriteToHost
            return
        }
    }

    end {
        Write-Verbose "Module uninstall completed."
    }
}
