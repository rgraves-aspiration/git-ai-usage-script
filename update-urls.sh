#!/bin/bash

# Script to update GitHub URLs after repository creation
# Usage: ./update-urls.sh YOUR-GITHUB-USERNAME

if [ -z "$1" ]; then
    echo "Usage: $0 YOUR-GITHUB-USERNAME"
    echo "Example: $0 johndoe"
    exit 1
fi

USERNAME="$1"
REPO_NAME="git-ai-usage-script"

echo "🔧 Updating URLs for GitHub username: $USERNAME"

# Update README.md
sed -i.bak "s/YOUR-USERNAME/$USERNAME/g" README.md
echo "✅ Updated README.md"

# Update install.sh
sed -i.bak "s/YOUR-USERNAME/$USERNAME/g" install.sh
echo "✅ Updated install.sh"

# Remove backup files
rm -f *.bak

echo ""
echo "🎉 All URLs updated!"
echo "📝 Next steps:"
echo "   1. Review the changes: git diff"
echo "   2. Commit the updates: git add . && git commit -m 'Update GitHub URLs'"
echo "   3. Push changes: git push"
echo ""
echo "🔗 Your repository: https://github.com/$USERNAME/$REPO_NAME"
echo "📦 One-liner install: curl -sSL https://raw.githubusercontent.com/$USERNAME/$REPO_NAME/main/install.sh | bash"
