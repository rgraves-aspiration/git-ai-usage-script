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
    # Check if alias already exists
    if ! grep -q "alias ai=" "$SHELL_RC" 2>/dev/null; then
        echo ""
        echo "🔧 Adding configuration to $SHELL_RC..."
        
        if [[ "$PATH_ADDED" == true ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
        fi
        
        echo 'alias ai="git-ai-usage"' >> "$SHELL_RC"
        
        echo "✅ Added 'ai' alias and PATH to $SHELL_RC"
        echo ""
        echo "🔄 To activate immediately, run:"
        echo "   source $SHELL_RC"
        echo ""
        echo "Or restart your terminal."
    else
        echo "✅ 'ai' alias already exists in $SHELL_RC"
    fi
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
