#!/bin/bash

# Universal Git AI Usage Analysis Script
# This script can be run from any git repository to analyze AI-assisted commits
# in branches matching a specified pattern.
#
# IMPLEMENTATION PLAN:
# 1. ✅ Default behavior: analyze only current branch
# 2. ✅ Replace --match with --branches flag (requires argument) → NOW: --include
# 3. ✅ Add --from flag for custom start date
# 4. ✅ Add --to flag for custom end date  
# 5. ✅ Add -v/--verbose flag for detailed pattern info
# 6. ✅ Add --remote flag to analyze remote branches instead of local
# 7. ✅ Change --branches to --include
# 8. ✅ Add --exclude flag (adds to exclusion list)
# 9. ✅ Add --local flag (works without args to scan all local branches)
# 10. ✅ Make --remote work without args to scan all remote branches
# 11. ✅ Change default date range to full history
# 12. ✅ Add relative timeframe support (2w, 6d, 3h45m, etc.)
#
# Usage: 
#   cd /path/to/your/git/repository
#   /path/to/git-ai-usage.sh [options]
#
# Examples:
#   /path/to/git-ai-usage.sh                           # Current branch only
#   /path/to/git-ai-usage.sh --include="rg/CPDE"       # Multiple branches matching pattern
#   /path/to/git-ai-usage.sh --local                   # All local branches
#   /path/to/git-ai-usage.sh --remote                  # All remote branches
#   /path/to/git-ai-usage.sh --from="2w"               # Past 2 weeks
#   /path/to/git-ai-usage.sh --from="3d"               # Past 3 days
#   /path/to/git-ai-usage.sh --exclude="staging"       # Add staging to exclusions
#   /path/to/git-ai-usage.sh -v                        # Verbose output

# --- Configuration ---
# Set the start date for analysis. Empty for full history.
# Examples: "2024-01-01", "3 months ago", "yesterday", "2w", "5d"
START_DATE=""  # Changed default to full history
END_DATE=""    # Empty for no end date limit

# Regex for your AI commit message tag.
# Use '\[AI-GENERATED\]' for exact match, or '\[AI-\]' for anything starting with [AI-
AI_TAG='\[AI'

# Default behavior: analyze only current branch (can be overridden with flags)
ANALYZE_CURRENT_BRANCH_ONLY=true
INCLUDE_BRANCH_PATTERNS=""
ANALYZE_REMOTE_BRANCHES=false
ANALYZE_LOCAL_BRANCHES=false
VERBOSE=false

# Regex patterns to EXCLUDE master and main branches, HEAD pointer and arrow notation
EXCLUDE_BRANCH_PATTERNS="^(origin/HEAD|origin/main|origin/master|main|master|HEAD)$|^.*->.*$"
ADDITIONAL_EXCLUDES=""  # For user-specified exclusions

# --- Function to parse relative time ---
# Converts relative time formats like "2w", "5d", "3h45m" to git-compatible format
parse_relative_time() {
    local input="$1"
    
    # If it's already an absolute date or git-compatible format, return as-is
    if [[ ! "$input" =~ ^[0-9]+[wdhm] ]]; then
        echo "$input"
        return
    fi
    
    # Initialize components
    local weeks=0 days=0 hours=0 minutes=0
    
    # Parse weeks (w) - must come before days
    if [[ "$input" =~ ([0-9]+)w ]]; then
        weeks=${BASH_REMATCH[1]}
        days=$((weeks * 7))
    fi
    
    # Parse days (d) - add to existing days from weeks
    if [[ "$input" =~ ([0-9]+)d ]]; then
        days=$((days + ${BASH_REMATCH[1]}))
    fi
    
    # Parse hours (h)
    if [[ "$input" =~ ([0-9]+)h ]]; then
        hours=${BASH_REMATCH[1]}
    fi
    
    # Parse minutes (m)
    if [[ "$input" =~ ([0-9]+)m ]]; then
        minutes=${BASH_REMATCH[1]}
    fi
    
    # Convert to total minutes
    local total_minutes=$((days * 24 * 60 + hours * 60 + minutes))
    
    # If only days/weeks specified (no hours/minutes), start from beginning of the day
    if [[ "$hours" -eq 0 && "$minutes" -eq 0 && "$days" -gt 0 ]]; then
        # Go to start of day X days ago
        if command -v gdate >/dev/null 2>&1; then
            # Use GNU date on macOS if available
            gdate -d "$days days ago" '+%Y-%m-%d 00:00:00'
        else
            # Use BSD date (macOS default)
            date -v-${days}d -v0H -v0M -v0S '+%Y-%m-%d %H:%M:%S'
        fi
    else
        # Calculate exact time ago
        if command -v gdate >/dev/null 2>&1; then
            # Use GNU date on macOS if available
            gdate -d "$total_minutes minutes ago" '+%Y-%m-%d %H:%M:%S'
        else
            # Use BSD date (macOS default)
            date -v-${total_minutes}M '+%Y-%m-%d %H:%M:%S'
        fi
    fi
}

# --- Parse command line arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --include=*)
            INCLUDE_BRANCH_PATTERNS="${1#*=}"
            ANALYZE_CURRENT_BRANCH_ONLY=false
            shift
            ;;
        --exclude=*)
            ADDITIONAL_EXCLUDES="${1#*=}"
            shift
            ;;
        --pattern=*)
            AI_TAG="${1#*=}"
            shift
            ;;
        --from=*)
            START_DATE=$(parse_relative_time "${1#*=}")
            shift
            ;;
        --to=*)
            END_DATE=$(parse_relative_time "${1#*=}")
            shift
            ;;
        --local)
            ANALYZE_LOCAL_BRANCHES=true
            ANALYZE_REMOTE_BRANCHES=false
            ANALYZE_CURRENT_BRANCH_ONLY=false
            shift
            ;;
        --remote)
            ANALYZE_REMOTE_BRANCHES=true
            ANALYZE_LOCAL_BRANCHES=false
            ANALYZE_CURRENT_BRANCH_ONLY=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --install)
            echo "🤖 Installing Git AI Usage Analysis Script..."
            
            # Create local bin directory
            mkdir -p "$HOME/.local/bin"
            
            # Copy this script to the local bin
            SCRIPT_PATH="$(realpath "$0")"
            cp "$SCRIPT_PATH" "$HOME/.local/bin/git-ai-usage"
            chmod +x "$HOME/.local/bin/git-ai-usage"
            
            echo "✅ Installed to $HOME/.local/bin/git-ai-usage"
            
            # Determine shell config file
            SHELL_RC=""
            if [[ "$SHELL" == *"zsh"* ]]; then
                SHELL_RC="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                SHELL_RC="$HOME/.bashrc"
            fi
            
            # Add to PATH if needed
            if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                echo "🔧 Adding $HOME/.local/bin to PATH..."
                if [[ -n "$SHELL_RC" ]]; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
                    echo "✅ Added to PATH in $(basename "$SHELL_RC")"
                fi
            fi
            
            # Check if 'ai' alias already exists
            ALIAS_EXISTS=false
            EXISTING_ALIAS=""
            if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
                if grep -q "alias ai=" "$SHELL_RC" 2>/dev/null; then
                    ALIAS_EXISTS=true
                    EXISTING_ALIAS=$(grep "alias ai=" "$SHELL_RC" | head -1)
                fi
            fi
            
            # Handle alias creation
            if [[ "$ALIAS_EXISTS" == true ]]; then
                echo ""
                echo "⚠️  Found existing 'ai' alias:"
                echo "   $EXISTING_ALIAS"
                echo ""
                echo "Choose an option:"
                echo "  1) Replace existing alias with git-ai-usage"
                echo "  2) Create a different alias (e.g., 'gai')"
                echo "  3) Skip alias creation"
                echo ""
                read -p "Enter choice (1-3): " CHOICE
                
                case $CHOICE in
                    1)
                        # Replace existing alias
                        if command -v sed >/dev/null 2>&1; then
                            sed -i.bak '/alias ai=/d' "$SHELL_RC"
                            echo 'alias ai="git-ai-usage"' >> "$SHELL_RC"
                            echo "✅ Replaced existing 'ai' alias"
                        else
                            echo "❌ Could not automatically replace alias. Please manually update:"
                            echo "   Remove: $EXISTING_ALIAS"
                            echo "   Add: alias ai=\"git-ai-usage\""
                        fi
                        ;;
                    2)
                        read -p "Enter new alias name (e.g., 'gai'): " NEW_ALIAS
                        if [[ -n "$NEW_ALIAS" && "$NEW_ALIAS" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
                            echo "alias $NEW_ALIAS=\"git-ai-usage\"" >> "$SHELL_RC"
                            echo "✅ Created '$NEW_ALIAS' alias"
                        else
                            echo "❌ Invalid alias name. Please manually add: alias YOUR_ALIAS=\"git-ai-usage\""
                        fi
                        ;;
                    3)
                        echo "⏭️  Skipped alias creation"
                        ;;
                    *)
                        echo "❌ Invalid choice. Skipped alias creation"
                        ;;
                esac
            else
                # No existing alias, create 'ai' alias
                if [[ -n "$SHELL_RC" ]]; then
                    echo 'alias ai="git-ai-usage"' >> "$SHELL_RC"
                    echo "✅ Created 'ai' alias in $(basename "$SHELL_RC")"
                fi
            fi
            
            echo ""
            echo "🎉 Installation complete! Usage:"
            echo "  cd /path/to/git/repo && ai"
            echo "  git-ai-usage --help"
            exit 0
            ;;
        --help|-h)
            echo "Git AI Usage Analysis Script"
            echo "============================="
            echo ""
            echo "USAGE:"
            echo "  $0 [options]"
            echo ""
            echo "OPTIONS:"
            echo "  --include=\"pattern\"   Analyze branches matching pattern (regex supported)"
            echo "  --exclude=\"pattern\"   Add pattern to exclusion list (appends to defaults)"
            echo "  --pattern=\"regex\"     Custom AI tag pattern (default: '\\[AI')"
            echo "  --local               Analyze all local branches (excludes current branch default)"
            echo "  --remote              Analyze all remote branches"
            echo "  --from=\"date\"         Start date for analysis (default: full history)"
            echo "  --to=\"date\"           End date for analysis (default: no limit)"
            echo "  -v, --verbose         Show detailed inclusion/exclusion patterns"
            echo "  --install             Install script to ~/.local/bin with 'ai' alias"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "DATE FORMATS:"
            echo "  Absolute:    2024-01-01, \"2024-12-25 14:30\""
            echo "  Git format:  \"3 months ago\", \"yesterday\", \"last week\""
            echo "  Relative:    2w (2 weeks), 5d (5 days), 3h45m (3 hours 45 minutes)"
            echo "               Combinations: 1w2d (1 week 2 days), 2d6h (2 days 6 hours)"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                                    # Current branch only"
            echo "  $0 --include=\"feature\"                # All branches containing 'feature'"
            echo "  $0 --include=\"rg/CPDE.*frontend\"      # Regex pattern matching"
            echo "  $0 --local                            # All local branches"
            echo "  $0 --remote                           # All remote branches"
            echo "  $0 --local --exclude=\"staging|temp\"   # Local branches excluding staging/temp"
            echo "  $0 --from=\"2w\"                        # Past 2 weeks from start of day"
            echo "  $0 --from=\"3d6h\"                      # Past 3 days 6 hours (exact time)"
            echo "  $0 --from=\"2024-01-01\" --to=\"1w\"     # From Jan 1st to 1 week ago"
            echo "  $0 --remote --include=\"main\" -v       # Remote main branch with verbose output"
            echo "  $0 --pattern=\"\\[AI-GENERATED\\]\"       # Custom AI tag pattern"
            echo "  $0 --pattern=\"Co-authored-by.*copilot\" # GitHub Copilot format"
            echo ""
            echo "NOTES:"
            echo "  • Default exclusions: master, main, HEAD, and arrow notation (origin/HEAD -> ...)"
            echo "  • --exclude adds to defaults, doesn't replace them"
            echo "  • Relative times: w=weeks, d=days, h=hours, m=minutes"
            echo "  • Only days/weeks specified will start from beginning of that day"
            echo "  • Including hours/minutes gives exact time calculation"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# --- Global Aggregators ---
OVERALL_TOTAL_LINES=0
OVERALL_AI_LINES=0
OVERALL_TOTAL_COMMITS=0
OVERALL_AI_COMMITS=0
BRANCHES_PROCESSED=0

# --- Color codes for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Function to calculate lines and commits for a single branch ---
# Takes branch name as argument
calculate_branch_stats() {
    local branch="$1"
    local date_clause=""

    # Build date range clause
    if [ -n "$START_DATE" ] && [ -n "$END_DATE" ]; then
        date_clause="--since=\"$START_DATE\" --until=\"$END_DATE\""
    elif [ -n "$START_DATE" ]; then
        date_clause="--since=\"$START_DATE\""
    elif [ -n "$END_DATE" ]; then
        date_clause="--until=\"$END_DATE\""
    fi

    echo -e "  ${BLUE}→${NC} Analyzing branch: ${CYAN}$branch${NC}"

    # Determine comparison base (for remote vs local branches)
    local comparison_base=""
    if [ "$ANALYZE_REMOTE_BRANCHES" = true ]; then
        comparison_base="^origin/master"
    else
        comparison_base="^origin/master"
    fi

    # Count lines added in commits that are in this branch but NOT in master
    # This avoids double-counting commits that exist in multiple branches
    current_branch_total_lines=$(eval "git log --no-merges --first-parent $date_clause \"$branch\" $comparison_base --pretty=format:%H | \
      xargs -r -I{} git show --format=\"\" --unified=0 {} | \
      grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

    current_branch_ai_lines=$(eval "git log --no-merges --first-parent $date_clause --grep=\"$AI_TAG\" \"$branch\" $comparison_base --pretty=format:%H | \
      xargs -r -I{} git show --format=\"\" --unified=0 {} | \
      grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

    # Count commits (unique to this branch)
    current_branch_total_commits=$(eval "git log --no-merges --first-parent $date_clause \"$branch\" $comparison_base --pretty=format:%H | wc -l")

    current_branch_ai_commits=$(eval "git log --no-merges --first-parent $date_clause --grep=\"$AI_TAG\" \"$branch\" $comparison_base --pretty=format:%H | wc -l")

    # Calculate percentages for this branch
    if [ "$current_branch_total_commits" -gt 0 ]; then
        branch_commit_percentage=$(awk "BEGIN {printf \"%.1f\", ($current_branch_ai_commits/$current_branch_total_commits)*100}")
    else
        branch_commit_percentage="0.0"
    fi

    if [ "$current_branch_total_lines" -gt 0 ]; then
        branch_lines_percentage=$(awk "BEGIN {printf \"%.1f\", ($current_branch_ai_lines/$current_branch_total_lines)*100}")
    else
        branch_lines_percentage="0.0"
    fi

    echo -e "    ${WHITE}Commits:${NC} $current_branch_total_commits total, ${GREEN}$current_branch_ai_commits AI${NC} (${YELLOW}${branch_commit_percentage}%${NC})"
    echo -e "    ${WHITE}Lines:${NC}   $current_branch_total_lines total, ${GREEN}$current_branch_ai_lines AI${NC} (${YELLOW}${branch_lines_percentage}%${NC})"
    echo ""

    # Add to overall accumulators
    OVERALL_TOTAL_LINES=$((OVERALL_TOTAL_LINES + current_branch_total_lines))
    OVERALL_AI_LINES=$((OVERALL_AI_LINES + current_branch_ai_lines))
    OVERALL_TOTAL_COMMITS=$((OVERALL_TOTAL_COMMITS + current_branch_total_commits))
    OVERALL_AI_COMMITS=$((OVERALL_AI_COMMITS + current_branch_ai_commits))
    BRANCHES_PROCESSED=$((BRANCHES_PROCESSED + 1))
}

# --- Main Script Logic ---

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository. Please run this script from within a git repository."
    exit 1
fi

# Get the current repository information
REPO_PATH=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_PATH")

# Get current branch if analyzing current branch only
if [ "$ANALYZE_CURRENT_BRANCH_ONLY" = true ]; then
    CURRENT_BRANCH=$(git branch --show-current)
    if [ -z "$CURRENT_BRANCH" ]; then
        echo -e "${RED}Error: Could not determine current branch${NC}"
        exit 1
    fi
fi

echo -e "\n${BOLD}🤖 Git AI Usage Analysis${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Repository:${NC} ${CYAN}$REPO_NAME${NC} ${WHITE}(${NC}$REPO_PATH${WHITE})${NC}"

# Display date range
if [ -n "$START_DATE" ] && [ -n "$END_DATE" ]; then
    echo -e "${WHITE}Date Range:${NC} ${START_DATE} to ${END_DATE}"
elif [ -n "$START_DATE" ]; then
    echo -e "${WHITE}Date Range:${NC} ${START_DATE} onwards"
elif [ -n "$END_DATE" ]; then
    echo -e "${WHITE}Date Range:${NC} up to ${END_DATE}"
else
    echo -e "${WHITE}Date Range:${NC} full history"
fi

echo -e "${WHITE}AI Pattern:${NC} ${YELLOW}$AI_TAG${NC}"

# Display analysis scope
if [ "$ANALYZE_CURRENT_BRANCH_ONLY" = true ]; then
    echo -e "${WHITE}Analysis Scope:${NC} Current branch only (${CYAN}$CURRENT_BRANCH${NC})"
else
    echo -e "${WHITE}Branch Pattern:${NC} ${YELLOW}$INCLUDE_BRANCH_PATTERNS${NC}"
    if [ "$ANALYZE_REMOTE_BRANCHES" = true ]; then
        echo -e "${WHITE}Branch Type:${NC} Remote branches"
    else
        echo -e "${WHITE}Branch Type:${NC} Local branches"
    fi
fi

# Combine default and additional exclusion patterns
FINAL_EXCLUDE_PATTERN="$EXCLUDE_BRANCH_PATTERNS"
if [ -n "$ADDITIONAL_EXCLUDES" ]; then
    FINAL_EXCLUDE_PATTERN="$EXCLUDE_BRANCH_PATTERNS|$ADDITIONAL_EXCLUDES"
fi

# Show verbose information if requested
if [ "$VERBOSE" = true ]; then
    echo -e "\n${BOLD}🔍 Verbose Information${NC}"
    echo -e "${WHITE}Include Pattern:${NC} ${YELLOW}$INCLUDE_BRANCH_PATTERNS${NC}"
    echo -e "${WHITE}Default Excludes:${NC} ${YELLOW}$EXCLUDE_BRANCH_PATTERNS${NC}"
    if [ -n "$ADDITIONAL_EXCLUDES" ]; then
        echo -e "${WHITE}Additional Excludes:${NC} ${YELLOW}$ADDITIONAL_EXCLUDES${NC}"
    fi
    echo -e "${WHITE}Final Exclude Pattern:${NC} ${YELLOW}$FINAL_EXCLUDE_PATTERN${NC}"
    echo -e "${WHITE}Remote Analysis:${NC} $ANALYZE_REMOTE_BRANCHES"
    echo -e "${WHITE}Local Analysis:${NC} $ANALYZE_LOCAL_BRANCHES"
    echo -e "${WHITE}Current Branch Only:${NC} $ANALYZE_CURRENT_BRANCH_ONLY"
fi

echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"

# 1. Fetch all remote branches to ensure local remote-tracking branches are up-to-date
echo -e "\n${BLUE}📡 Fetching latest changes...${NC}"
git fetch --all --prune > /dev/null 2>&1

# 2. Analyze Branches
echo -e "\n${BOLD}📊 Branch Analysis${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"

if [ "$ANALYZE_CURRENT_BRANCH_ONLY" = true ]; then
    # Analyze only the current branch
    calculate_branch_stats "$CURRENT_BRANCH"
else
    # Analyze multiple branches based on pattern or flags
    if [ "$ANALYZE_REMOTE_BRANCHES" = true ]; then
        # Remote branches
        if [ -n "$INCLUDE_BRANCH_PATTERNS" ]; then
            BRANCHES=$(git branch -r | sed 's/^[ ]*//; s/[ ]*$//' | grep "$INCLUDE_BRANCH_PATTERNS" | grep -vE "$FINAL_EXCLUDE_PATTERN" | grep -v '^$')
        else
            BRANCHES=$(git branch -r | sed 's/^[ ]*//; s/[ ]*$//' | grep -vE "$FINAL_EXCLUDE_PATTERN" | grep -v '^$')
        fi
        BRANCH_TYPE="remote"
    elif [ "$ANALYZE_LOCAL_BRANCHES" = true ]; then
        # Local branches  
        if [ -n "$INCLUDE_BRANCH_PATTERNS" ]; then
            BRANCHES=$(git branch | grep "$INCLUDE_BRANCH_PATTERNS" | grep -vE "$FINAL_EXCLUDE_PATTERN" | sed 's/^[ ]*\* //' | sed 's/^[ ]*//')
        else
            BRANCHES=$(git branch | grep -vE "$FINAL_EXCLUDE_PATTERN" | sed 's/^[ ]*\* //' | sed 's/^[ ]*//')
        fi
        BRANCH_TYPE="local"
    else
        # Legacy behavior - require include pattern
        if [ -n "$INCLUDE_BRANCH_PATTERNS" ]; then
            BRANCHES=$(git branch | grep "$INCLUDE_BRANCH_PATTERNS" | grep -vE "$FINAL_EXCLUDE_PATTERN" | sed 's/^[ ]*\* //' | sed 's/^[ ]*//')
            BRANCH_TYPE="local (pattern-matched)"
        else
            echo -e "${RED}❌ No analysis method specified. Use --include, --local, or --remote${NC}"
            exit 1
        fi
    fi

    if [ -z "$BRANCHES" ]; then
        if [ -n "$INCLUDE_BRANCH_PATTERNS" ]; then
            echo -e "${RED}❌ No $BRANCH_TYPE branches found matching pattern: '${YELLOW}$INCLUDE_BRANCH_PATTERNS${RED}'${NC}"
        else
            echo -e "${RED}❌ No $BRANCH_TYPE branches found after applying exclusions${NC}"
        fi
    else
        for branch in $BRANCHES; do
            calculate_branch_stats "$branch"
        done
    fi
fi

# --- Overall Aggregated Results ---
echo -e "\n${BOLD}📈 Summary Results${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"

if [ "$ANALYZE_CURRENT_BRANCH_ONLY" = true ]; then
    echo -e "${WHITE}Analysis:${NC} Current branch (${CYAN}$CURRENT_BRANCH${NC})"
else
    echo -e "${WHITE}Branches analyzed:${NC} ${CYAN}$BRANCHES_PROCESSED${NC}"
fi

echo -e "\n${BOLD}📝 COMMITS${NC}"
echo -e "${WHITE}Total commits:${NC}     ${BOLD}$OVERALL_TOTAL_COMMITS${NC}"
echo -e "${WHITE}AI-assisted:${NC}       ${GREEN}$OVERALL_AI_COMMITS${NC}"

if [ "$OVERALL_TOTAL_COMMITS" -gt 0 ]; then
    COMMITS_PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($OVERALL_AI_COMMITS/$OVERALL_TOTAL_COMMITS)*100}")
    echo -e "${WHITE}AI commit ratio:${NC}   ${YELLOW}${BOLD}${COMMITS_PERCENTAGE}%${NC}"
else
    echo -e "${WHITE}AI commit ratio:${NC}   ${RED}N/A (no commits found)${NC}"
fi

echo -e "\n${BOLD}💻 LINES OF CODE${NC}"
echo -e "${WHITE}Total lines added:${NC} ${BOLD}$OVERALL_TOTAL_LINES${NC}"
echo -e "${WHITE}AI-assisted:${NC}       ${GREEN}$OVERALL_AI_LINES${NC}"

if [ "$OVERALL_TOTAL_LINES" -gt 0 ]; then
    # Use awk for floating-point calculation
    LINES_PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($OVERALL_AI_LINES/$OVERALL_TOTAL_LINES)*100}")
    echo -e "${WHITE}AI lines ratio:${NC}    ${YELLOW}${BOLD}${LINES_PERCENTAGE}%${NC}"
else
    echo -e "${WHITE}AI lines ratio:${NC}    ${RED}N/A (no lines found)${NC}"
fi

echo -e "\n${GREEN}✅ Analysis Complete!${NC}"