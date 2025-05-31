# This wrapper function has been removed as it provided no added value.
# It was purely routing parameters to the actual functions without validation,
# error handling, or business logic. Users should call the specific functions directly:
#
# Instead of: Invoke-DevModuleOperation -GitHubRepo "owner/repo"
# Use: Install-DevModule -GitHubRepo "owner/repo"
#
# Instead of: Invoke-DevModuleOperation -List
# Use: Get-InstalledDevModule
#
# Instead of: Invoke-DevModuleOperation -Remove "ModuleName"
# Use: Uninstall-DevModule -Name "ModuleName"
#
# Instead of: Invoke-DevModuleOperation -Update "ModuleName" 
# Use: Update-DevModule -Name "ModuleName"
#
# This improves maintainability by removing unnecessary indirection.
