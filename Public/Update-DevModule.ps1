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
# Load private helper for GitHub update
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) '../Private/Update-DevModuleFromGitHub.ps1')

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
            # Get the first user-writable path from PSModulePath (inline Get-DevModulesPath logic)
            $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
            foreach ($path in $modulePaths) {
                if ($path -like "*$env:HOME*" -or $path -like "*$env:USERPROFILE*") {
                    $InstallPath = $path
                    break
                }
            }
        }
        Write-Verbose "Starting update of module: $Name"
    }

    process {
        try {
            # Get existing module information
            $module = Get-InstalledDevModule -Name $Name -InstallPath $InstallPath
            if (-not $module) {
                Write-Warning "Module '$Name' is not installed. Use Install-DevModule to install it first."
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
                    Write-Information "Module update cancelled by user." -InformationAction Continue
                    return
                }
            }

            if ($PSCmdlet.ShouldProcess($Name, "Update module")) {
                $updatedModule = switch ($module.SourceType) {
                    'Local' {
                        # Inline Update-DevModuleFromLocal logic
                        Write-Verbose "Updating module '$($module.Name)' from local source: $($module.SourcePath)"

                        # Validate source still exists
                        if (-not (Test-Path $module.SourcePath -PathType Container)) {
                            throw "Source path no longer exists: $($module.SourcePath)"
                        }

                        # Find and validate module manifest in source
                        $manifestFiles = Get-ChildItem -Path $module.SourcePath -Filter '*.psd1' -ErrorAction SilentlyContinue
                        if ($manifestFiles.Count -eq 0) {
                            throw "No PowerShell module manifest (.psd1) found in source: $($module.SourcePath)"
                        }

                        $manifestFile = $manifestFiles[0]
                        
                        # Inline Get-ModuleVersionFromManifest logic
                        try {
                            $manifest = Import-PowerShellDataFile -Path $manifestFile.FullName
                            $newVersion = if ($manifest.ModuleVersion) { $manifest.ModuleVersion.ToString() } else { "1.0.0" }
                        }
                        catch {
                            Write-Warning "Failed to read module version, using 1.0.0"
                            $newVersion = "1.0.0"
                        }
                        
                        Write-Verbose "Found module manifest: $($manifestFile.Name)"
                        Write-Verbose "Updating to version: $newVersion"

                        # Extract install paths
                        $versionPath = $module.InstallPath
                        $moduleBasePath = Split-Path $versionPath -Parent
                        $installBasePath = Split-Path $moduleBasePath -Parent
                        $newDestinationPath = Join-Path $moduleBasePath $newVersion

                        # Remove existing version directory if it exists
                        if (Test-Path $newDestinationPath) {
                            Remove-Item -Path $newDestinationPath -Recurse -Force
                            Write-Verbose "Removed existing version directory: $newDestinationPath"
                        }

                        # Create new version directory and copy files
                        New-Item -Path $newDestinationPath -ItemType Directory -Force | Out-Null
                        Write-Verbose "Created new version directory: $newDestinationPath"
                        
                        $ProgressPreference = 'SilentlyContinue'
                        Copy-Item -Path (Join-Path $module.SourcePath '*') -Destination $newDestinationPath -Recurse -Force
                        Write-Verbose "Copied updated module files"

                        # Reload module if it's currently loaded
                        if (Get-Module -Name $module.Name -ErrorAction SilentlyContinue) {
                            Remove-Module -Name $module.Name -Force
                            Import-Module $module.Name -Force
                            Write-Verbose "Reloaded module in current session"
                        }

                        Write-Verbose "Successfully updated module '$($module.Name)' to version '$newVersion' from local source"
                        
                        # Return the updated module object
                        Get-InstalledDevModule -Name $module.Name -InstallPath $installBasePath
                    }
                    'GitHub' {
                        # Call the private GitHub update function
                        $params = @{
                            Module = $module
                        }
                        if ($PersonalAccessToken) { 
                            $params.PersonalAccessToken = $PersonalAccessToken 
                        }
                        
                        Update-DevModuleFromGitHub @params
                    }
                    default {
                        Write-Error "Unknown source type: $($module.SourceType)" -Category InvalidData
                        return
                    }
                }

                # Update the metadata LastUpdated timestamp (inline Get-ModuleMetadataPath logic)
                $metadataPath = Join-Path $InstallPath '.metadata'
                $metadataFile = Join-Path $metadataPath "$Name.json"
                
                if (Test-Path $metadataFile) {
                    $metadata = Get-Content $metadataFile -Force | ConvertFrom-Json
                    # Add LastUpdated property if it doesn't exist
                    if (-not $metadata.PSObject.Properties['LastUpdated']) {
                        $metadata | Add-Member -MemberType NoteProperty -Name 'LastUpdated' -Value $null
                    }
                    $metadata.LastUpdated = (Get-Date).ToString('o')
                    $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Force
                    Write-Verbose "Updated metadata timestamp for module: $Name"
                }

                Write-Information "Successfully updated module: $Name" -InformationAction Continue
                
                # Return the updated module object
                return $updatedModule
            }
        }
        catch {
            Write-Error "Failed to update module '$Name': $($_.Exception.Message)" -Category OperationStopped
            return
        }
    }

    end {
        Write-Verbose "Module update completed."
    }
}
