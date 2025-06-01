# Changelog

All notable changes to PoShDevModules will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-05-31

### Added
- **Install-DevModule**: Install PowerShell modules from local development paths or GitHub repositories
- **Get-InstalledDevModule**: List and query all installed development modules with metadata
- **Update-DevModule**: Update modules from their original sources (local or GitHub)
- **Uninstall-DevModule**: Clean removal of modules with complete metadata cleanup
- **Cross-platform support**: Works on Windows, macOS, and Linux
- **Version management**: Automatic versioning with side-by-side installations
- **GitHub integration**: Direct installation from GitHub repositories with branch/path support
- **Comprehensive metadata tracking**: Installation sources, versions, and update history
- **Complete test suite**: 25/30 tests passing with platform-appropriate skips
- **Production-ready documentation**: Complete help system and examples

### Features
- Module installation from local development paths
- Direct GitHub repository installation with branch and subdirectory support
- Automatic version detection and management
- Side-by-side version installations
- Source tracking for updates
- Cross-platform path handling
- ShouldProcess support for safe destructive operations
- Pipeline input support for batch operations
- Comprehensive error handling and validation

### Technical Details
- PowerShell 5.1+ compatibility
- No external dependencies required
- Git integration (optional) for enhanced GitHub handling
- Secure module loading and validation
- Production-ready metadata management

[1.0.0]: https://github.com/dgeddes/PoShDevModules/releases/tag/v1.0.0