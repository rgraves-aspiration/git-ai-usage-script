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
DEBUG=false
PARENT_BRANCH=""  # Optional base branch for more accurate current branch analysis

# Minimum expected script size for update verification (bytes)
# Based on current script size (~25KB), 10KB ensures we have a valid script
# while allowing for size variations. Protects against network errors returning
# empty files, error pages, or truncated downloads.
MIN_VALID_SCRIPT_SIZE_BYTES=10000

# Regex patterns to EXCLUDE master and main branches, HEAD pointer and arrow notation
EXCLUDE_BRANCH_PATTERNS="^(origin/HEAD|origin/main|origin/master|main|master|HEAD)$|^.*->.*$"
ADDITIONAL_EXCLUDES=""  # For user-specified exclusions

# Parent branch detection configuration
GIT_LOG_LIMIT=100               # Number of commits to analyze in git graph for parent detection
BEST_DISTANCE_THRESHOLD=500     # Maximum distance threshold for considering a branch as parent
EXACT_PARENT_PREFERENCE=10000   # Strong preference bonus for exact parent matches

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

# --- Function to download script from GitHub ---
# Downloads the script from the specified URL to the given target file
download_script() {
    local url="$1"
    local target="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$url" -o "$target"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$target"
    else
        echo "❌ Error: Neither curl nor wget found. Please install one of them."
        exit 1
    fi
}

# --- Function to perform script update ---
# Downloads and replaces the current script with the latest version from GitHub
perform_update() {
    echo "🔄 Updating Git AI Usage Analysis Script..."
    
    # Check if script is installed (look for it in common locations)
    INSTALLED_SCRIPT=""
    if [ -f "$HOME/.local/bin/git-ai-usage" ]; then
        INSTALLED_SCRIPT="$HOME/.local/bin/git-ai-usage"
    elif command -v git-ai-usage >/dev/null 2>&1; then
        INSTALLED_SCRIPT=$(command -v git-ai-usage)
    else
        echo "❌ Error: git-ai-usage not found in PATH. Please install first using:"
        echo "   curl -sSL https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/install.sh | bash"
        exit 1
    fi
    
    echo "📍 Found installed script at: $INSTALLED_SCRIPT"
    
    # Download the latest version
    echo "⬇️  Downloading latest version..."
    TEMP_SCRIPT=$(mktemp /tmp/git-ai-usage-update-XXXXXXXXXX)
    trap 'rm -f "$TEMP_SCRIPT"' EXIT
    
    download_script "https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/git-ai-usage.sh" "$TEMP_SCRIPT"
    
    # Verify download
    if [ ! -f "$TEMP_SCRIPT" ] || [ ! -s "$TEMP_SCRIPT" ]; then
        echo "❌ Error: Failed to download the latest version."
        exit 1
    fi
    
    # Basic integrity check - ensure file size is reasonable
    ACTUAL_SIZE=$(wc -c < "$TEMP_SCRIPT" 2>/dev/null || echo "0")
    if [ "$ACTUAL_SIZE" -lt "$MIN_VALID_SCRIPT_SIZE_BYTES" ]; then
        echo "❌ Error: Downloaded file appears to be too small ($ACTUAL_SIZE bytes, expected at least $MIN_VALID_SCRIPT_SIZE_BYTES bytes)"
        echo "   This may indicate a network error or the file was not downloaded correctly."
        exit 1
    fi
    
    # Verify it looks like a shell script (flexible shebang check)
    if ! head -1 "$TEMP_SCRIPT" | grep -q "^#!.*bash"; then
        echo "❌ Error: Downloaded file doesn't appear to be a valid bash script"
        exit 1
    fi
    
    # Replace the installed version
    echo "🔄 Updating installed script..."
    
    # Check for write permissions on the target location
    if [ ! -w "$INSTALLED_SCRIPT" ] && [ ! -w "$(dirname "$INSTALLED_SCRIPT")" ]; then
        echo "❌ Error: Insufficient permissions to update the installed script at '$INSTALLED_SCRIPT'."
        echo "   Please rerun this script with 'sudo' or ensure you have write access to the target location."
        exit 1
    fi
    
    cp "$TEMP_SCRIPT" "$INSTALLED_SCRIPT"
    chmod +x "$INSTALLED_SCRIPT"
    
    # Clear shell command cache to ensure updated script is used
    hash -r 2>/dev/null || true
    
    echo "✅ Update complete!"
    echo ""
    echo "🔍 To verify the update worked:"
    echo "   git-ai-usage --help"
    echo ""
    echo "💡 If you're running this from a local copy, remember to use the installed version:"
    echo "   Use: git-ai-usage (or your alias like 'ai')"
    echo "   Not: ./git-ai-usage.sh"
    exit 0
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
        --parent=*)
            PARENT_BRANCH="${1#*=}"
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
        --debug)
            DEBUG=true
            VERBOSE=true  # Debug implies verbose
            shift
            ;;
        --update)
            perform_update
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
            echo "  --parent=\"branch\"      Specify base branch for more accurate current branch analysis"
            echo "  --local               Analyze all local branches (excludes current branch default)"
            echo "  --remote              Analyze all remote branches"
            echo "  --from=\"date\"         Start date for analysis (default: full history)"
            echo "  --to=\"date\"           End date for analysis (default: no limit)"
            echo "  -v, --verbose         Show detailed inclusion/exclusion patterns"
            echo "  --debug               Show detailed base branch detection process"
            echo "  --update              Update to the latest version from GitHub"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "DATE FORMATS:"
            echo "  Absolute:    2024-01-01, \"2024-12-25 14:30\""
            echo "  Git format:  \"3 months ago\", \"yesterday\", \"last week\""
            echo "  Relative:    2w (2 weeks), 5d (5 days), 3h45m (3 hours 45 minutes)"
            echo "               Combinations: 1w2d (1 week 2 days), 2d6h (2 days 6 hours)"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                                    # Current branch (auto-detects base branch)"
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
            echo "  $0 --parent=\"main\"                    # Specify base branch explicitly"
            echo "  $0 --update                           # Update to latest version from GitHub"
            echo ""
            echo "NOTES:"
            echo "  • Current branch analysis automatically detects the most likely base branch"
            echo "  • Shows commits unique to the current branch (excluding base branch commits)"
            echo "  • Falls back to default branch comparison if no clear parent is detected"
            echo "  • Default branch analysis includes all commits when analyzed directly"
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

# --- Function to detect the default branch ---
# Determines the main/master/default branch for comparison
detect_default_branch() {
    # First, try to get the default branch from origin
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    
    if [ -n "$default_branch" ]; then
        echo "$default_branch"
        return
    fi
    
    # If that fails, check common branch names
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        echo "main"
        return
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        echo "master"
        return
    elif git show-ref --verify --quiet refs/heads/main; then
        echo "main"
        return
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
        return
    fi
    
    # Last resort: use the current branch or first available branch
    local current=$(git branch --show-current 2>/dev/null)
    if [ -n "$current" ]; then
        echo "$current"
    else
        echo "HEAD"
    fi
}

# --- Function to detect the parent branch ---
# Uses git log --graph to accurately detect where a branch diverged from
# This directly reads the git graph structure for 100% accuracy
detect_parent_branch() {
    local branch="$1"
    local default_branch=$(detect_default_branch)
    
    # Debug output
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}🔍 DEBUG: Parent branch detection for '${branch}' using git graph${NC}" >&2
        echo -e "   Default branch: ${default_branch}" >&2
    fi
    
    # If user specified a parent branch explicitly, use it
    if [ -n "$PARENT_BRANCH" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   Using user-specified parent: ${PARENT_BRANCH}" >&2
        fi
        echo "$PARENT_BRANCH"
        return
    fi
    
    # If we're analyzing the default branch itself, no parent needed
    if [ "$branch" = "$default_branch" ] || [ "$branch" = "origin/$default_branch" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   Branch is default branch - no parent needed" >&2
        fi
        echo ""
        return
    fi
    
    # Use git log --graph to find where this branch diverged from
    if [ "$DEBUG" = true ]; then
        echo -e "   Using git log --graph to find divergence point..." >&2
    fi
    
    # Get all branches that could be potential parents (exclude current branch and standard exclusions)
    local all_branches=$(git for-each-ref --format="%(refname:short)" refs/heads refs/remotes 2>/dev/null | \
        grep -vE "^(${branch}|origin/${branch}|HEAD|.* -> .*)$")
    
    if [ "$DEBUG" = true ]; then
        echo -e "   Candidate branches: $(echo $all_branches | wc -w) total" >&2
    fi
    
    # Get a reasonable amount of git graph to analyze (default: last GIT_LOG_LIMIT commits)
    local graph_output=$(git log --graph --oneline --format="%h %s" --all -n "$GIT_LOG_LIMIT" 2>/dev/null)
    
    if [ -z "$graph_output" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   Could not get git graph - falling back to default branch" >&2
        fi
        echo "$default_branch"
        return
    fi
    
    # Find the first commit that appears on our branch in the graph
    local first_branch_commit=$(git rev-list "$branch" --max-count=1 2>/dev/null)
    
    if [ -z "$first_branch_commit" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   Could not get first commit on branch - falling back to default" >&2
        fi
        echo "$default_branch"
        return
    fi
    
    # Get short hash for pattern matching
    local short_hash=$(echo "$first_branch_commit" | cut -c1-7)
    
    if [ "$DEBUG" = true ]; then
        echo -e "   Looking for commit ${short_hash} in git graph..." >&2
    fi
    
    # Find the line in the graph that contains our commit
    local commit_line=$(echo "$graph_output" | grep -n "$short_hash" | head -1)
    
    if [ -z "$commit_line" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   Commit not found in recent graph - falling back to default" >&2
        fi
        echo "$default_branch"
        return
    fi
    
    # Extract line number
    local line_number=$(echo "$commit_line" | cut -d: -f1)
    
    if [ "$DEBUG" = true ]; then
        echo -e "   Found commit at line ${line_number} in graph" >&2
        echo -e "   Graph line: $(echo "$commit_line" | cut -d: -f2-)" >&2
    fi
    
    # Check each candidate branch to see which one appears most recently before our commit
    local best_parent=""
    local best_distance=99999
    
    for candidate in $all_branches; do
        # Skip if candidate doesn't exist
        if ! git show-ref --verify --quiet "refs/heads/$candidate" && \
           ! git show-ref --verify --quiet "refs/remotes/$candidate"; then
            continue
        fi
        
        # Check if this candidate is an ancestor of our branch
        if ! git merge-base --is-ancestor "$candidate" "$branch" 2>/dev/null; then
            if [ "$DEBUG" = true ]; then
                echo -e "   ${candidate}: Not an ancestor, skipping" >&2
            fi
            continue
        fi
        
        # Get the merge base distance (lower is better - means more recent common ancestor)
        local merge_base=$(git merge-base "$candidate" "$branch" 2>/dev/null)
        if [ -z "$merge_base" ]; then
            continue
        fi
        
        # Count commits from merge base to our branch (smaller means closer relationship)
        local distance=$(git rev-list --count "$merge_base".."$branch" 2>/dev/null || echo "99999")
        
        # Also check if the candidate's HEAD is exactly the merge base (perfect match)
        local candidate_head=$(git rev-parse "$candidate" 2>/dev/null)
        local is_exact_parent=false
        if [ "$candidate_head" = "$merge_base" ]; then
            is_exact_parent=true
            distance=$((distance - EXACT_PARENT_PREFERENCE))  # Strong preference for exact parent
        fi
        
        if [ "$DEBUG" = true ]; then
            if [ "$is_exact_parent" = true ]; then
                echo -e "   ${candidate}: distance=${distance} (EXACT PARENT - merge-base matches HEAD)" >&2
            else
                echo -e "   ${candidate}: distance=${distance}" >&2
            fi
        fi
        
        # Update best candidate if this one is closer
        if [ "$distance" -lt "$best_distance" ]; then
            best_parent="$candidate"
            best_distance="$distance"
            if [ "$DEBUG" = true ]; then
                echo -e "   ${candidate}: New best parent (distance: ${distance})" >&2
            fi
        fi
    done
    
    # Strategy 2: Fallback to tracking branch if no clear winner
    if [ -z "$best_parent" ] || [ "$best_distance" -gt "$BEST_DISTANCE_THRESHOLD" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   No clear parent found, checking tracking branch..." >&2
        fi
        
        local tracking_branch=""
        if [[ "$branch" != origin/* ]]; then
            tracking_branch=$(git config "branch.$branch.merge" 2>/dev/null | sed 's|refs/heads/||')
            if [ -n "$tracking_branch" ]; then
                local remote=$(git config "branch.$branch.remote" 2>/dev/null || echo "origin")
                if [ "$remote" != "." ] && [ "$tracking_branch" != "$branch" ]; then
                    local full_tracking="$remote/$tracking_branch"
                    if git show-ref --verify --quiet "refs/remotes/$full_tracking" && \
                       git merge-base --is-ancestor "$full_tracking" "$branch" 2>/dev/null; then
                        if [ "$DEBUG" = true ]; then
                            echo -e "   Found tracking branch: ${tracking_branch}" >&2
                        fi
                        echo "$tracking_branch"
                        return
                    fi
                fi
            fi
        fi
    fi
    
    # Return the best candidate or fall back to default
    if [ -n "$best_parent" ]; then
        if [ "$DEBUG" = true ]; then
            echo -e "   RESULT: Best parent '${best_parent}' (distance: ${best_distance})" >&2
        fi
        echo "$best_parent"
    else
        if [ "$DEBUG" = true ]; then
            echo -e "   RESULT: No suitable parent found, using default branch '${default_branch}'" >&2
        fi
        echo "$default_branch"
    fi
}

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

    # Intelligently detect the best comparison base (parent branch)
    local comparison_base=""
    local default_branch=$(detect_default_branch)
    
    # Only include all commits if we're analyzing the default branch itself
    if [ "$branch" = "$default_branch" ] || [ "$branch" = "origin/$default_branch" ]; then
        # When analyzing the default branch itself, include all commits
        comparison_base=""
        echo -e "    ${PURPLE}Note: Analyzing default branch - including all commits${NC}"
    else
        # Try to detect the most likely parent branch
        local parent_branch=$(detect_parent_branch "$branch")
        
        # Show helpful note when using explicit parent or non-default parent detection
        if [ -n "$PARENT_BRANCH" ]; then
            echo -e "    ${PURPLE}Using specified parent branch '$parent_branch'${NC}"
        elif [ "$parent_branch" != "$default_branch" ]; then
            echo -e "    ${PURPLE}Auto-detected parent branch '$parent_branch'${NC}"
        fi
        
        # Set up comparison base
        if [ "$ANALYZE_REMOTE_BRANCHES" = true ]; then
            comparison_base="^origin/$parent_branch"
        else
            comparison_base="^$parent_branch"
        fi
        
        # Check if the comparison base exists, if not, fall back to default branch
        if ! git show-ref --verify --quiet "refs/remotes/origin/$parent_branch" && ! git show-ref --verify --quiet "refs/heads/$parent_branch"; then
            echo -e "    ${YELLOW}Warning: Parent branch '$parent_branch' not found - falling back to $default_branch${NC}"
            if [ "$ANALYZE_REMOTE_BRANCHES" = true ]; then
                comparison_base="^origin/$default_branch"
            else
                comparison_base="^$default_branch"
            fi
            
            # Final check for default branch
            if ! git show-ref --verify --quiet "refs/remotes/origin/$default_branch" && ! git show-ref --verify --quiet "refs/heads/$default_branch"; then
                comparison_base=""
                echo -e "    ${YELLOW}Warning: No suitable parent branch found - analyzing all commits${NC}"
            fi
        fi
    fi

    # Count lines added in commits 
    if [ -n "$comparison_base" ]; then
        # Exclude commits that are in the parent branch (show only commits unique to this branch)
        current_branch_total_lines=$(eval "git log --no-merges $date_clause \"$branch\" $comparison_base --pretty=format:%H 2>/dev/null | \
          xargs -r -I{} git show --format=\"\" --unified=0 {} | \
          grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

        current_branch_ai_lines=$(eval "git log --no-merges $date_clause --grep=\"$AI_TAG\" \"$branch\" $comparison_base --pretty=format:%H 2>/dev/null | \
          xargs -r -I{} git show --format=\"\" --unified=0 {} | \
          grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

        # Count commits (unique to this branch)
        current_branch_total_commits=$(eval "git log --no-merges $date_clause \"$branch\" $comparison_base --oneline 2>/dev/null | wc -l")

        current_branch_ai_commits=$(eval "git log --no-merges $date_clause --grep=\"$AI_TAG\" \"$branch\" $comparison_base --oneline 2>/dev/null | wc -l")
    else
        # Include all commits on this branch (for current branch analysis)
        current_branch_total_lines=$(eval "git log --no-merges $date_clause \"$branch\" --pretty=format:%H 2>/dev/null | \
          xargs -r -I{} git show --format=\"\" --unified=0 {} | \
          grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

        current_branch_ai_lines=$(eval "git log --no-merges $date_clause --grep=\"$AI_TAG\" \"$branch\" --pretty=format:%H 2>/dev/null | \
          xargs -r -I{} git show --format=\"\" --unified=0 {} | \
          grep -E \"^\+\" | grep -vE \"^\+\+\+\" | wc -l")

        # Count commits
        current_branch_total_commits=$(eval "git log --no-merges $date_clause \"$branch\" --oneline 2>/dev/null | wc -l")

        current_branch_ai_commits=$(eval "git log --no-merges $date_clause --grep=\"$AI_TAG\" \"$branch\" --oneline 2>/dev/null | wc -l")
    fi

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
    
    # Show parent branch detection details for current branch analysis
    if [ "$ANALYZE_CURRENT_BRANCH_ONLY" = true ]; then
        detected_parent=$(detect_parent_branch "$CURRENT_BRANCH")
        default_branch=$(detect_default_branch)
        echo -e "${WHITE}Default Branch:${NC} ${CYAN}$default_branch${NC}"
        if [ -n "$PARENT_BRANCH" ]; then
            echo -e "${WHITE}Base Branch:${NC} ${GREEN}$PARENT_BRANCH${NC} ${YELLOW}(user-specified)${NC}"
        elif [ -n "$detected_parent" ] && [ "$detected_parent" != "$default_branch" ]; then
            echo -e "${WHITE}Base Branch:${NC} ${GREEN}$detected_parent${NC} ${YELLOW}(auto-detected)${NC}"
        elif [ -n "$detected_parent" ] && [ "$detected_parent" = "$default_branch" ]; then
            echo -e "${WHITE}Base Branch:${NC} ${GREEN}$detected_parent${NC} ${YELLOW}(auto-detected)${NC}"
        else
            echo -e "${WHITE}Base Branch:${NC} ${GREEN}$default_branch${NC} ${YELLOW}(default fallback)${NC}"
        fi
    fi
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