# Git AI Usage Analysis Script 🤖

A powerful Bash script to analyze AI-assisted code contributions in your git repositories. Quickly see how much of your codebase was written with AI assistance!

## ⚡ Quick Install

### 🚀 One-liner Installation (Recommended):
```bash
curl -sSL https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/install.sh | bash
```

### 📦 Alternative Installation Methods:

#### Git Clone + Install:
```bash
git clone https://github.com/rgraves-aspiration/git-ai-usage-script.git
cd git-ai-usage-script
./install.sh
```

#### Direct Script Download:
```bash
# Download and install with installer script
curl -sSL https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/install.sh | bash
```

> **Note:** When using `curl | bash`, interactive prompts for alias conflicts will be skipped. If you have an existing `ai` alias, you'll need to manually add your preferred alias after installation:
> ```bash
> echo 'alias ai="git-ai-usage"' >> ~/.zshrc    # Replace existing 'ai' alias
> echo 'alias gai="git-ai-usage"' >> ~/.zshrc   # Or create a different alias
> ```

#### Interactive Installation (recommended for alias conflicts):
```bash
# Download installer first, then run interactively
curl -sSL https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/install.sh > install.sh
chmod +x install.sh
./install.sh
rm install.sh
```

#### Quick Try (no installation):
```bash
curl -sSL https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/git-ai-usage.sh | bash
```

### 🔧 For Development Teams:

#### NPM-style (if your team uses Node.js):
```bash
# Clone and link for development
git clone https://github.com/rgraves-aspiration/git-ai-usage-script.git
cd git-ai-usage-script
npm link
```

## 🚀 Usage

After installation, use the `ai` alias from any git repository:

```bash
# Basic usage
ai                          # Analyze current branch
ai --help                   # Show all options
ai --update                 # Update to latest version

# Branch analysis
ai --local                  # All local branches
ai --remote                 # All remote branches  
ai --include="feature"      # Branches matching pattern
ai --parent="main"          # Specify parent branch for current branch analysis

# Time ranges
ai --from="2w"              # Past 2 weeks
ai --from="5d"              # Past 5 days
ai --from="3h30m"           # Past 3 hours 30 minutes
ai --from="2024-01-01"      # Since specific date

# Advanced usage
ai --local --exclude="staging|temp" -v  # Exclude patterns, verbose output
ai --remote --include="main" --from="1w" # Remote main branch, past week
ai --pattern="\[AI-GENERATED\]" --local  # Custom AI tag pattern
ai --pattern="Co-authored-by.*copilot"   # GitHub Copilot format
ai --parent="develop"                     # Explicitly specify parent branch

# Updates
ai --update                              # Update to latest version from GitHub
```

## 📊 Sample Output

```
🤖 Git AI Usage Analysis
═══════════════════════════════════════════════════════════
Repository: my-project (/path/to/my-project)
Date Range: 2025-06-18 00:00:00 onwards
AI Pattern: \[AI
Analysis Scope: Current branch only (feature/new-ui)
Parent Branch: main (auto-detected)
═══════════════════════════════════════════════════════════

📊 Branch Analysis
─────────────────────────────────────────────────────────────
  → Analyzing branch: feature/new-ui
    Commits: 23 total, 18 AI (78.3%)
    Lines:   1,247 total, 1,156 AI (92.7%)

📈 Summary Results
═══════════════════════════════════════════════════════════
Analysis: Current branch (feature/new-ui vs main)

📝 COMMITS
Total commits:     23
AI-assisted:      18
AI commit ratio:   78.3%

💻 LINES OF CODE
Total lines added: 1,247
AI-assisted:      1,156
AI lines ratio:    92.7%

✅ Analysis Complete!
```

## ⚙️ Configuration

### 🌿 Branch Analysis & Parent Detection

When analyzing the **current branch**, the script automatically:
- **Auto-detects the parent branch** using git merge-base analysis
- **Shows only commits unique to your branch** (excludes commits from the parent/default branch)
- **Falls back to default branch** (main/master) if no clear parent is detected
- **Uses explicit parent** when you specify `--parent="branch-name"`

**Parent Branch Detection Logic:**
```bash
# Automatic detection (recommended)
ai                           # Auto-detects parent and shows unique commits

# Explicit parent specification  
ai --parent="develop"        # Use 'develop' as parent branch
ai --parent="main"           # Use 'main' as parent branch
```

**Why Parent Detection Matters:**
- **Feature branches** show only their new commits, not inherited ones
- **Sub-branches** (e.g., `feature/auth/login-form` branched from `feature/auth`) correctly detect their immediate parent
- **Accurate metrics** for branch-specific AI contribution analysis

### 🎯 AI Tag Pattern Matching

The script looks for commit messages containing `[AI` by default. You can customize this using the `--pattern` flag:

```bash
# For exact match: [AI-GENERATED]
ai --pattern="\[AI-GENERATED\]" --local

# For any AI prefix: [AI-ASSISTED], [AI-GENERATED], etc.
ai --pattern="\[AI" --local

# For different formats: (AI), <AI>, etc.
ai --pattern="\(AI\)" --local

# For GitHub Copilot format
ai --pattern="Co-authored-by.*copilot" --local
```

**Tip**: Use the `--pattern` flag with any analysis command to customize AI detection on the fly!

### 🔧 Installation Notes

During installation, the script will:
- Check if an `ai` alias already exists
- Prompt you to replace it, create a different alias, or skip alias creation
- Automatically add the install directory to your PATH if needed

This ensures safe installation without overwriting your existing aliases.


## 🔧 Development & Customization

### 🛠️ Local Development:
```bash
git clone https://github.com/rgraves-aspiration/git-ai-usage-script.git
cd git-ai-usage-script

# Test the script
./git-ai-usage.sh --help

# Install locally for testing
./install.sh
```

### 🎨 Customization Options:

#### Custom Exclusion Patterns:
```bash
# Use --exclude flag to add to default exclusions
ai --local --exclude="staging|demo|temp"

# Default exclusions are automatically applied:
# master, main, HEAD, origin/HEAD, origin/main, origin/master, and arrow notation
```

