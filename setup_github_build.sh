#!/bin/bash

echo "🚀 GitHub Actions APK Build Setup"
echo "=================================="
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "📦 Initializing git repository..."
    git init
    echo "✅ Git initialized"
else
    echo "✅ Git repository already exists"
fi

# Check if remote exists
if ! git remote | grep -q "origin"; then
    echo ""
    echo "❓ Enter your GitHub repository URL:"
    echo "   Example: https://github.com/username/sports-app.git"
    read -p "   URL: " repo_url
    
    if [ -n "$repo_url" ]; then
        git remote add origin "$repo_url"
        echo "✅ Remote added: $repo_url"
    else
        echo "⚠️  No URL provided. You can add it later with:"
        echo "   git remote add origin YOUR_REPO_URL"
    fi
else
    echo "✅ Remote 'origin' already configured"
    git remote -v
fi

echo ""
echo "📝 Adding files to git..."
git add .github/workflows/build-apk.yml
git add GITHUB_ACTIONS_APK_BUILD.md

echo ""
echo "💾 Committing changes..."
git commit -m "Add GitHub Actions APK build workflow" 2>/dev/null || echo "⚠️  No changes to commit (already committed?)"

echo ""
echo "📤 Ready to push!"
echo ""
echo "Next steps:"
echo "1. Run: git push -u origin main"
echo "   (or 'git push -u origin master' if your branch is master)"
echo ""
echo "2. Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/actions"
echo ""
echo "3. Click 'Build Android APK' → 'Run workflow'"
echo ""
echo "4. Wait 5-10 minutes, then download APK from Artifacts"
echo ""
echo "🎉 Done! Your APK will be built in the cloud!"
