# Changelog

All notable changes to this project will be documented in this file.

## [1.3.2] - 2025-06-27

### Fixed
- **Parent Branch Detection**: Completely rewrote parent branch detection to use git log --graph for 100% accuracy
- **Commit Counting**: Fixed bug where commit counting returned 0 due to missing newlines in git log output
- Parent detection now uses actual git graph structure instead of heuristics
- Prioritizes exact tip matches for parent detection with merge-base distance as tiebreaker
- Falls back to tracking branch or default branch when no clear parent is found

### Improved  
- Parent detection now works reliably on complex repositories with multiple feature branches
- More accurate commit counting by switching from --pretty=format:%H to --oneline
- Better debug output for parent branch detection process
- Enhanced reliability for repos with non-standard branching patterns

### Code Quality
- Added configurable constants `GIT_LOG_LIMIT`, `BEST_DISTANCE_THRESHOLD`, and `EXACT_PARENT_PREFERENCE` for better maintainability
- Removed unused variables to clean up codebase
- Replaced all magic numbers with named constants per code review feedback
- Improved code readability and configurability

## [1.3.1] - 2025-06-25

### Fixed
- Improved parent branch detection to avoid selecting very old/inactive branches
- Added 6-month activity filter to exclude ancient branches from parent detection
- Parent detection now prefers the most recent valid parent among candidates
- Fixed cross-platform date command compatibility for BSD and GNU systems
- Cleaner output when falling back to default branch (no confusing auto-detection messages)

## [1.3.0] - 2025-06-25

### Added
- Intelligent parent branch detection for more accurate analysis of feature branches
- Automatically detects the most likely parent branch instead of always comparing to default branch
- Shows commits truly unique to the current branch when analyzing sub-branches
- `--parent` flag to explicitly specify parent branch for comparison

### Fixed
- Current branch analysis now correctly shows only commits unique to that branch (excluding commits from default branch)
- Added clear messaging to indicate when analyzing default branch vs feature branch
- Updated help text to clarify branch analysis behavior

### Improved
- Enhanced parent branch detection to include both local and remote branches
- Optimized Git operations for better performance in large repositories
- Reduced redundant Git command calls through batched operations

## [1.2.1] - 2025-06-25

### Fixed
- Installer now properly handles non-interactive mode (e.g., when piped from curl)
- Added clear messaging when interactive prompts are skipped due to piped installation
- Improved README documentation with alternative installation methods for interactive prompts

## [1.2.0] - 2025-06-25

### Added
- `--update` command to update script to latest version from GitHub
- Automatic detection of installed script location for updates
- Download verification with file size and script header validation

### Changed
- Updated package.json version to 1.2.0 for proper release tagging
- Enhanced update process with integrity checks

## [1.1.0] - 2025-06-25

### Added
- `--pattern` flag for custom AI tag patterns (supports regex)
- Enhanced installer with alias conflict detection
- GitHub Copilot development instructions and policies

### Changed
- Removed integrated `--install` flag in favor of standalone installer
- Improved installer alias handling (detects conflicts, offers alternatives)
- Fixed default branch detection for repositories using 'main' vs 'master'
- Updated installation documentation to use standalone installer
- Clarified commit message format requirements in development guidelines

### Removed
- `--install` flag from main script (use standalone `install.sh` instead)

### Fixed  
- Default branch comparison logic now works with both 'main' and 'master'
- Improved error handling for repositories without default branch setup
- Installer now prevents duplicate PATH entries on subsequent installations

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
