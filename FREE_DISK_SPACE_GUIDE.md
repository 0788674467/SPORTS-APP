# Free Disk Space on Your Mac

## Current Issue
Your Mac has only **229MB free** (99% full). You need at least **2-3GB free** to build the APK.

## Quick Fixes (Do These First)

### 1. Empty Trash
```bash
# Empty trash from command line
rm -rf ~/.Trash/*
```

### 2. Clear System Caches
```bash
# Clear user caches (safe)
rm -rf ~/Library/Caches/*

# Clear system logs
sudo rm -rf /private/var/log/*
```

### 3. Clear Flutter Build Caches
```bash
cd frontend
flutter clean
rm -rf build/
rm -rf .dart_tool/
```

### 4. Clear Gradle Caches (Android Build)
```bash
rm -rf ~/.gradle/caches/
rm -rf ~/.android/build-cache/
```

### 5. Clear Homebrew Caches
```bash
brew cleanup -s
rm -rf ~/Library/Caches/Homebrew/*
```

## Check Disk Space

```bash
df -h
```

Look for the line with `/` - that's your main disk.

## Find Large Files

### Find largest directories:
```bash
du -sh ~/* | sort -hr | head -20
```

### Find large files over 100MB:
```bash
find ~ -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | sort -hr | head -20
```

## Common Space Hogs

### 1. Downloads Folder
```bash
# Check size
du -sh ~/Downloads

# Clean old files (older than 30 days)
find ~/Downloads -type f -mtime +30 -delete
```

### 2. Docker (if installed)
```bash
docker system prune -a --volumes
```

### 3. Node Modules
```bash
# Find all node_modules folders
find ~ -name "node_modules" -type d -prune 2>/dev/null

# Delete old ones (be careful!)
find ~ -name "node_modules" -type d -prune -mtime +30 -exec rm -rf {} \; 2>/dev/null
```

### 4. Old iOS Simulators
```bash
xcrun simctl delete unavailable
```

### 5. Xcode Derived Data
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### 6. Old Log Files
```bash
rm -rf ~/Library/Logs/*
rm -rf frontend/flutter_*.log
```

## Alternative: Build on Another Machine

If you can't free up space, you have options:

### Option 1: Use GitHub Actions (Free)
Create `.github/workflows/build-apk.yml`:
```yaml
name: Build APK
on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.4'
      - run: cd frontend && flutter pub get
      - run: cd frontend && flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: frontend/build/app/outputs/flutter-apk/app-release.apk
```

Then:
1. Push to GitHub
2. Go to Actions tab
3. Run "Build APK" workflow
4. Download the APK

### Option 2: Use a Friend's Computer
1. Copy the project to their computer
2. Install Flutter
3. Run the build command
4. Copy the APK back

### Option 3: Use Codemagic (Free tier available)
1. Sign up at codemagic.io
2. Connect your repository
3. Configure build
4. Download APK

## After Freeing Space

Once you have at least 2-3GB free:

```bash
cd frontend
./build_apk.sh
```

## How Much Space Do You Need?

- **Minimum**: 2GB free
- **Recommended**: 5GB free
- **Comfortable**: 10GB+ free

## Check What's Using Space

### macOS Storage Management:
1. Click Apple menu → About This Mac
2. Click Storage tab
3. Click Manage
4. Review recommendations

### Terminal command:
```bash
# Show disk usage by directory
ncdu ~
```

(Install ncdu if needed: `brew install ncdu`)

## Emergency: Delete Old Projects

If you have old projects you don't need:

```bash
# List projects by size
du -sh ~/Projects/* | sort -hr

# Delete old ones (BE CAREFUL!)
rm -rf ~/Projects/old-project-name
```

## Summary

**Quick wins** (run these now):
```bash
# 1. Empty trash
rm -rf ~/.Trash/*

# 2. Clear caches
rm -rf ~/Library/Caches/*

# 3. Clear Flutter build
cd frontend && flutter clean

# 4. Clear Gradle
rm -rf ~/.gradle/caches/

# 5. Clear logs
rm -rf frontend/flutter_*.log

# 6. Check space
df -h
```

After freeing space, try building again:
```bash
cd frontend
./build_apk.sh
```
