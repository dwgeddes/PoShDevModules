# Production Installation Guide

## Quick Installation

### Method 1: Self-Install (Recommended)
```powershell
# Download and run the self-install script
./Tools/SelfInstall.ps1
```

### Method 2: Manual Installation  
```powershell
# Import the module directly
Import-Module ./PoShDevModules.psd1
```

## Verification

```powershell
# Verify installation
Get-Module PoShDevModules
Get-Command -Module PoShDevModules

# Test basic functionality
Get-InstalledDevModule
```

## First Steps

```powershell
# Install your first development module
Install-DevModule -Name "MyModule" -SourcePath "./path/to/your/module"

# List installed modules
Get-InstalledDevModule

# Get help for any function
Get-Help Install-DevModule -Full
```

## System Requirements

- PowerShell 5.1+ (PowerShell 7+ recommended)
- Windows, macOS, or Linux
- Internet access for GitHub installations

## Next Steps

- Read the full [README.md](../README.md) for complete documentation
- See [CompleteWorkflowDemo.ps1](./CompleteWorkflowDemo.ps1) for usage examples
- Run tests with [RunAllTests.ps1](./RunAllTests.ps1) to validate installation
