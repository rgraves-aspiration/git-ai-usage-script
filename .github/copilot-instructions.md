# Git AI Usage Script - Copilot Instructions

## AI Assistant Development Guidelines

These instructions guide AI assistants (like GitHub Copilot, Claude, etc.) when contributing to this project.

## 🏷️ Commit Message Standards

### Required AI Tag Format
All commits made with AI assistance MUST include an AI tag at the END of the ONE-LINE commit message in the format:
```
<commit message> [AI <Tool> <Model>]
```

**Examples:**
- `Add --pattern flag for custom AI tag detection [AI CopilotIDE Sonnet]`
- `Fix alias detection in installer script [AI GitHub Copilot]`
- `Update README with new configuration options [AI Claude]`
- `Implement relative time parsing function [AI ChatGPT GPT-4]`

**For multi-line commits:**
```
Remove --install flag from main script [AI CopilotIDE Sonnet]

The --install functionality is redundant with the standalone installer.
Keeping only install.sh simplifies maintenance and follows Unix conventions.
```

**IMPORTANT**: The AI tag goes at the end of the FIRST LINE (one-line summary), NOT in the detailed description.

### Tag Components
- **Tool**: The AI tool used (CopilotIDE, GitHub, Claude, ChatGPT, etc.)
- **Model**: The specific model when known (Sonnet, GPT-4, etc.)
- **Message**: Clear, descriptive commit message following conventional commit format

## 🌿 Branch Naming Convention

Use clean, descriptive branch names following this pattern:
```
<type>/<description>
```

**Types:**
- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions or improvements

**Examples:**
- `feature/pattern-flag-and-alias-handling`
- `fix/installer-path-detection`
- `docs/update-installation-guide`
- `refactor/simplify-branch-analysis`

## 📋 Development Workflow

### 1. Feature Implementation
- Create feature branch from `main`
- Implement changes with proper AI tags
- Test functionality thoroughly
- Update documentation as needed

### 2. Commit Strategy
- Make atomic commits (one logical change per commit)
- Each commit should include the AI tag
- Write descriptive commit messages
- Test each commit individually when possible

### 3. Documentation Requirements
- Update README.md for user-facing changes
- Update help text in scripts for new flags
- Add examples for new functionality
- Update CHANGELOG.md for releases

## 🛠️ Code Standards

### Bash Scripting
- Use proper error handling (`set -e` where appropriate)
- Include help text for all new flags
- Validate user input
- Provide meaningful error messages
- Use consistent formatting and indentation

### Documentation
- Use clear, concise language
- Include practical examples
- Use emojis consistently for visual appeal
- Keep installation instructions up-to-date
- Document breaking changes prominently

## 🔍 Testing Requirements

Before committing:
- Test all new flags and options
- Verify backward compatibility
- Test installation process
- Validate help text and documentation
- Test edge cases and error conditions

## 🎯 Project-Specific Guidelines

### AI Tag Detection
- Default pattern: `\[AI` (matches `[AI`, `[AI-GENERATED]`, etc.)
- Support regex patterns via `--pattern` flag
- Document common patterns (GitHub Copilot, etc.)

### Branch Analysis
- Default: current branch only
- Support local/remote branch analysis
- Allow inclusion/exclusion patterns
- Provide clear, colorful output

### Installation Safety
- Always check for existing aliases
- Prompt user for alias conflicts
- Provide alternative alias options
- Never overwrite without permission

## 📖 Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Bash Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Git Branch Naming](https://gist.github.com/digitaljhelms/4287848)

---

*This file ensures consistent AI-assisted development practices across all contributors.*
