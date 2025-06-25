#!/bin/bash

# Git AI Usage Analysis Script Installer
# This script downloads and installs the git-ai-usage script with the 'ai' alias

set -e  # Exit on any error

echo "🤖 Git AI Usage Analysis Script Installer"
echo "=========================================="
echo ""

# Configuration
SCRIPT_URL="https://raw.githubusercontent.com/rgraves-aspiration/git-ai-usage-script/main/git-ai-usage.sh"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="git-ai-usage"

# Create install directory
echo "📁 Creating install directory..."
mkdir -p "$INSTALL_DIR"

# Download the script
echo "⬇️  Downloading script..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$SCRIPT_URL" -O "$INSTALL_DIR/$SCRIPT_NAME"
else
    echo "❌ Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "✅ Script installed to $INSTALL_DIR/$SCRIPT_NAME"

# Add to PATH if needed
PATH_ADDED=false
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "🔧 Adding $INSTALL_DIR to PATH..."
    PATH_ADDED=true
fi

# Add alias based on shell
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    # Add PATH if needed
    if [[ "$PATH_ADDED" == true ]]; then
        echo ""
        echo "🔧 Adding $INSTALL_DIR to PATH in $(basename "$SHELL_RC")..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    fi
    
    # Check if 'ai' alias already exists
    ALIAS_EXISTS=false
    EXISTING_ALIAS=""
    if [[ -f "$SHELL_RC" ]] && grep -q "alias ai=" "$SHELL_RC" 2>/dev/null; then
        ALIAS_EXISTS=true
        EXISTING_ALIAS=$(grep "alias ai=" "$SHELL_RC" | head -1)
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
                    echo "✅ Replaced existing 'ai' alias in $(basename "$SHELL_RC")"
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
                    echo "✅ Created '$NEW_ALIAS' alias in $(basename "$SHELL_RC")"
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
        echo ""
        echo "🔧 Adding 'ai' alias to $(basename "$SHELL_RC")..."
        echo 'alias ai="git-ai-usage"' >> "$SHELL_RC"
        echo "✅ Added 'ai' alias to $(basename "$SHELL_RC")"
    fi
    
    echo ""
    echo "🔄 To activate immediately, run:"
    echo "   source $SHELL_RC"
    echo ""
    echo "Or restart your terminal."
else
    echo "⚠️  Could not detect shell type. You may need to manually add:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "   alias ai=\"git-ai-usage\""
    echo "   to your shell configuration file."
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📖 Usage:"
echo "   cd /path/to/git/repository"
echo "   ai                    # Analyze current branch"
echo "   ai --help             # Show all options"
echo "   ai --local --from=2w  # Analyze local branches from past 2 weeks"
echo ""
echo "🔗 For more information, visit:"
echo "   https://github.com/rgraves-aspiration/git-ai-usage-script"
