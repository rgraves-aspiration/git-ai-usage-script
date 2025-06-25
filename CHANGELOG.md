# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-06-25

### Added
- Initial release of Git AI Usage Analysis Script
- Support for analyzing current branch, multiple branches, local and remote branches
- Flexible date range support (absolute, relative, git formats)
- Relative time parsing (2w, 5d, 3h45m, etc.)
- Pattern-based branch inclusion and exclusion
- Verbose output mode
- Colorized terminal output with emojis
- Built-in installation system with shell alias setup
- Cross-platform support (macOS/Linux)

### Features
- `--include` flag for branch pattern matching
- `--exclude` flag for additional exclusion patterns
- `--local` and `--remote` flags for branch type selection
- `--from` and `--to` flags for date range specification
- `--verbose` flag for detailed analysis information
- `--install` flag for easy system installation
- Smart relative time parsing (days only = start of day, with hours = exact time)
- Comprehensive help documentation

### Installation Options
- One-liner curl installation
- Git clone + script install  
- Direct script download with --install flag
- Simplified NPM package for Node.js teams

### Analysis Features
- Commit count and percentage analysis
- Lines of code count and percentage analysis
- Per-branch detailed statistics
- Aggregated summary across multiple branches
- Exclusion of merge commits and system branches
- Configurable AI tag pattern matching
