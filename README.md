# PoShDevModules

A PowerShell module for managing development modules from local paths and GitHub repositories with version control and cross-platform support.

## Overview

PoShDevModules simplifies the development workflow for PowerShell module creators by providing a standardized way to:
- Install modules from local development paths
- Install modules directly from GitHub repositories 
- Manage versioned module installations
- Update and uninstall development modules
- Maintain metadata for tracking module sources and versions

## Features

- 🔧 **Local Development**: Install modules from local file paths for active development
- 🌐 **GitHub Integration**: Direct installation from GitHub repositories
- 📦 **Version Management**: Automatic versioning and side-by-side installations
- 🖥️ **Cross-Platform**: Works on Windows, macOS, and Linux
- 🔄 **Update Tracking**: Track and update modules from their original sources
- 📊 **Metadata Management**: Comprehensive tracking of installation sources and history

## Installation

### From Source
```powershell
# Clone or download this repository
Import-Module ./PoShDevModules.psd1
```

### Quick Start Installation
```powershell
# Use the included self-install script
./Tools/SelfInstall.ps1
```

## Quick Start

### Install a Local Module
```powershell
# Install a module from your local development path
Install-DevModule -Name "MyModule" -SourcePath "./src/MyModule" 

# The module is now available for import
Import-Module MyModule
```

### Install from GitHub
```powershell
# Install directly from a GitHub repository
Install-DevModule -Name "PowerShellModule" -GitHubRepo "user/repository"

# Or with specific branch and subdirectory
Install-DevModule -Name "MyModule" -GitHubRepo "user/repo" -Branch "develop" -ModuleSubPath "src/MyModule"
```

### Manage Installed Modules
```powershell
# List all installed development modules
Get-InstalledDevModule

# Update a module from its source
Update-DevModule -Name "MyModule"

# Remove a module
Uninstall-DevModule -Name "MyModule"
```

## Requirements

- **PowerShell**: 5.1 or later (PowerShell 7+ recommended)
- **Operating System**: Windows, macOS, or Linux
- **Internet Access**: Required for GitHub module installations
- **Git** (optional): For enhanced GitHub repository handling

## Core Functions

### Install-DevModule
Installs a PowerShell module from a local path or GitHub repository.

```powershell
# Local installation
Install-DevModule -Name "MyModule" -SourcePath "./path/to/module"

# GitHub installation  
Install-DevModule -Name "MyModule" -GitHubRepo "owner/repository"
```

### Get-InstalledDevModule
Lists installed development modules with metadata.

```powershell
# List all modules
Get-InstalledDevModule

# Get specific module
Get-InstalledDevModule -Name "MyModule"
```

### Update-DevModule
Updates an installed module from its original source.

```powershell
Update-DevModule -Name "MyModule"
```

### Uninstall-DevModule
Removes an installed development module.

```powershell
Uninstall-DevModule -Name "MyModule"
```

## Configuration

### Default Installation Path
- **Windows**: `~/Documents/PowerShell/DevModules`
- **macOS/Linux**: `~/.local/share/powershell/DevModules`

### Custom Installation Path
```powershell
# Use custom path for all operations
$customPath = "/path/to/custom/modules"
Install-DevModule -Name "MyModule" -SourcePath "./src" -InstallPath $customPath
Get-InstalledDevModule -InstallPath $customPath
```

## Examples

### Development Workflow
```powershell
# 1. Install your module under development
Install-DevModule -Name "MyAwesomeModule" -SourcePath "./src/MyAwesomeModule"

# 2. Use the module
Import-Module MyAwesomeModule
Test-MyAwesomeFunction

# 3. Make changes to source code, then update
Update-DevModule -Name "MyAwesomeModule"

# 4. Test changes
Remove-Module MyAwesomeModule
Import-Module MyAwesomeModule -Force
Test-MyAwesomeFunction  # Now uses updated code
```

### GitHub Integration
```powershell
# Install from GitHub with Personal Access Token for private repos
$pat = Read-Host -AsSecureString "Enter GitHub PAT"
Install-DevModule -Name "PrivateModule" -GitHubRepo "user/private-repo" -PersonalAccessToken $pat

# Install from specific branch
Install-DevModule -Name "DevModule" -GitHubRepo "user/repo" -Branch "feature-branch"

# Install when module is in subdirectory
Install-DevModule -Name "NestedModule" -GitHubRepo "user/repo" -ModuleSubPath "modules/NestedModule"
```

### Team Development
```powershell
# Team lead shares module location
$sharedModuleRepo = "company/shared-powershell-modules"

# Team members install the same modules
Install-DevModule -Name "CompanyModule1" -GitHubRepo $sharedModuleRepo -ModuleSubPath "modules/CompanyModule1"
Install-DevModule -Name "CompanyModule2" -GitHubRepo $sharedModuleRepo -ModuleSubPath "modules/CompanyModule2"

# Easy updates when changes are pushed
Update-DevModule -Name "CompanyModule1"
Update-DevModule -Name "CompanyModule2"
```

## Architecture

PoShDevModules uses a versioned installation approach:
- Each module version is stored in its own directory
- Metadata tracks source information for updates
- Cross-platform path handling ensures compatibility
- Atomic operations prevent partial installations

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### Version 1.0.0
- Initial release
- Local module installation and management
- GitHub repository integration
- Cross-platform support
- Version management with metadata tracking
- Complete test suite with workflow validation
