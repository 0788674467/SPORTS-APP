#!/bin/bash

echo "🧹 Cleaning up disk space..."
echo "=============================="
echo ""

# Check current space
echo "📊 Current disk space:"
df -h / | grep -v Filesystem
echo ""

# 1. Empty trash
echo "🗑️  Emptying trash..."
rm -rf ~/.Trash/* 2>/dev/null
echo "   ✅ Trash emptied"

# 2. Clear user caches
echo "🧹 Clearing user caches..."
rm -rf ~/Library/Caches/* 2>/dev/null
echo "   ✅ User caches cleared"

# 3. Clear Flutter build
echo "🧹 Clearing Flutter build files..."
cd frontend 2>/dev/null && flutter clean 2>/dev/null
rm -rf frontend/build/ 2>/dev/null
rm -rf frontend/.dart_tool/ 2>/dev/null
echo "   ✅ Flutter build cleared"

# 4. Clear Gradle caches
echo "🧹 Clearing Gradle caches..."
rm -rf ~/.gradle/caches/ 2>/dev/null
rm -rf ~/.android/build-cache/ 2>/dev/null
echo "   ✅ Gradle caches cleared"

# 5. Clear old logs
echo "🧹 Clearing old log files..."
rm -rf ~/Library/Logs/* 2>/dev/null
rm -rf frontend/flutter_*.log 2>/dev/null
echo "   ✅ Logs cleared"

# 6. Clear Homebrew caches
echo "🧹 Clearing Homebrew caches..."
brew cleanup -s 2>/dev/null
rm -rf ~/Library/Caches/Homebrew/* 2>/dev/null
echo "   ✅ Homebrew caches cleared"

echo ""
echo "📊 New disk space:"
df -h / | grep -v Filesystem
echo ""
echo "✅ Cleanup complete!"
echo ""
echo "💡 If you still need more space, check:"
echo "   - ~/Downloads folder"
echo "   - Old projects"
echo "   - Docker images (docker system prune -a)"
echo ""
