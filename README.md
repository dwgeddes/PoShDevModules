# PoShDevModules

A PowerShell module that facilitates limited management of PowerShell modules from local paths or GitHub repositories without needing to publish to NuGet repositories. The purpose is to make it easier to manage modules still under development.

## Features

- **Install modules from local paths** - Install PowerShell modules directly from filesystem locations
- **Install modules from GitHub** - Download and install modules from GitHub repositories  
- **Update modules** - Update installed development modules from their original sources
- **List installed modules** - View all installed development modules with metadata
- **Remove modules** - Clean removal of development modules
- **Cross-platform support** - Works on Windows, macOS, and Linux

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/dgeddes/PoShDevModules.git
   cd PoShDevModules
   ```

2. Import the module:
   ```powershell
   Import-Module ./PoShDevModules.psd1
   ```

## Usage

### Install a module from GitHub
```powershell
Install-DevModule -GitHubRepo "user/repository" -PersonalAccessToken "your_token"
```

### Install a module from a local path
```powershell
Install-DevModule -SourcePath "/path/to/your/module"
```

### List installed development modules
```powershell
Get-InstalledDevModule
```

### Update a module
```powershell
Update-DevModule -Name "ModuleName" -PersonalAccessToken "your_token"
```

### Uninstall a module
```powershell
Uninstall-DevModule -Name "ModuleName"
```

### Use the convenience function (equivalent to original script)
```powershell
Invoke-DevModuleOperation -GitHubRepo "user/repo" -Force
Invoke-DevModuleOperation -List
Invoke-DevModuleOperation -Remove "ModuleName"
```

## Available Functions

| Function | Description |
|----------|-------------|
| `Install-DevModule` | Install a module from local path or GitHub repository |
| `Get-InstalledDevModule` | List all installed development modules |
| `Update-DevModule` | Update an installed module from its original source |
| `Uninstall-DevModule` | Uninstall an installed development module |
| `Invoke-DevModuleOperation` | Convenience function providing the original script interface |

## Advanced Options

### Custom Installation Path
```powershell
Install-DevModule -GitHubRepo "user/repo" -InstallPath "/custom/path"
```

### Branch Selection
```powershell
Install-DevModule -GitHubRepo "user/repo" -Branch "develop"
```

### Module Subdirectory
```powershell
Install-DevModule -GitHubRepo "user/repo" -ModuleSubPath "src/MyModule"
```

### Skip Auto-Import
```powershell
Install-DevModule -SourcePath "/path/to/module" -SkipImport
```

## Module Structure

```
PoShDevModules/
├── PoShDevModules.psd1          # Module manifest
├── PoShDevModules.psm1          # Main module file
├── Public/                      # Public functions
│   ├── Install-DevModule.ps1
│   ├── Get-InstalledDevModule.ps1
│   ├── Update-DevModule.ps1
│   └── Uninstall-DevModule.ps1
└── Private/                     # Internal helper functions
    ├── Install-DevModuleFromLocal.ps1
    ├── Install-DevModuleFromGitHub.ps1
    ├── Update-DevModuleFromLocal.ps1
    ├── Update-DevModuleFromGitHub.ps1
    ├── Save-ModuleMetadata.ps1
    ├── Get-GitHubRepoInfo.ps1
    └── Invoke-StandardErrorHandling.ps1
```

## Migration from DevModules.ps1

The original `DevModules.ps1` script has been converted into a proper PowerShell module. You can still use the same syntax with the `Invoke-DevModuleOperation` function:

```powershell
# Old way
./DevModules.ps1 -GitHubRepo "user/repo" -Force

# New way (equivalent)
Invoke-DevModuleOperation -GitHubRepo "user/repo" -Force
```

## Requirements

- PowerShell 5.1 or later
- Internet connection (for GitHub installations)
- Git (for some advanced scenarios)

## License

MIT License - see [LICENSE](LICENSE) file for details.
