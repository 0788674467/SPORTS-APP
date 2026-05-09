# GitHub Actions APK Build Guide

## What This Does
Automatically builds your Android APK in the cloud (GitHub's servers) - **no local disk space needed!**

## Setup Steps

### 1. Push Your Code to GitHub

If you haven't already:

```bash
# Initialize git (if not done)
git init

# Add all files
git add .

# Commit
git commit -m "Add GitHub Actions APK build workflow"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Push to GitHub
git push -u origin main
```

Or if you already have a repo:

```bash
git add .github/workflows/build-apk.yml
git commit -m "Add GitHub Actions APK build workflow"
git push
```

### 2. Trigger the Build

**Option A: Automatic (on every push)**
- Just push code to the `main` or `master` branch
- The workflow will run automatically
- Only triggers when files in `frontend/` folder change

**Option B: Manual (on-demand)**
1. Go to your GitHub repository
2. Click the **"Actions"** tab at the top
3. Click **"Build Android APK"** in the left sidebar
4. Click **"Run workflow"** button (top right)
5. Click the green **"Run workflow"** button in the dropdown
6. Wait 5-10 minutes for the build to complete

### 3. Download Your APK

After the build completes:

1. Go to the **Actions** tab
2. Click on the completed workflow run (green checkmark ✅)
3. Scroll down to **"Artifacts"** section
4. Click **"app-release-apk"** to download
5. Extract the ZIP file
6. You'll find `app-release.apk` inside

## Build Status

You can see the build status in your repository:
- Green checkmark ✅ = Build successful
- Red X ❌ = Build failed
- Yellow circle 🟡 = Build in progress

## What Gets Built

The workflow builds:
- **app-release.apk** - Single APK that works on all Android devices (~30-50 MB)

## Build Time

- First build: ~8-10 minutes
- Subsequent builds: ~5-7 minutes (with caching)

## Free Tier Limits

GitHub Actions free tier includes:
- **2,000 minutes/month** for private repos
- **Unlimited** for public repos
- Each build uses ~5-10 minutes

So you can build:
- **200-400 APKs per month** on private repos
- **Unlimited** on public repos

## Troubleshooting

### Build Failed?

1. Click on the failed workflow run
2. Click on the "Build APK" job
3. Expand the failed step to see the error
4. Common issues:
   - **Dependency error**: Update `pubspec.yaml`
   - **Build error**: Check your Dart/Flutter code
   - **Gradle error**: Usually auto-fixed by GitHub Actions

### APK Not Appearing?

- Wait for the green checkmark ✅
- Refresh the page
- Check the "Artifacts" section at the bottom

### Want to Build Split APKs?

Edit `.github/workflows/build-apk.yml` and change:
```yaml
flutter build apk --release
```
to:
```yaml
flutter build apk --split-per-abi --release
```

This creates 3 smaller APKs (one per architecture).

## Advanced: Auto-Release

Want to automatically create a GitHub Release with the APK?

Add this step to the workflow (after Upload APK):

```yaml
- name: 🚀 Create Release
  uses: softprops/action-gh-release@v1
  if: startsWith(github.ref, 'refs/tags/')
  with:
    files: frontend/build/app/outputs/flutter-apk/app-release.apk
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Then create a tag and push:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Monitoring Builds

### Email Notifications
GitHub will email you when builds fail (if enabled in your settings).

### Status Badge
Add this to your README.md to show build status:

```markdown
![Build APK](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build-apk.yml/badge.svg)
```

## Local vs GitHub Actions

| Feature | Local Build | GitHub Actions |
|---------|-------------|----------------|
| Disk Space | Need 5GB+ | None needed |
| Build Time | 5-10 min | 5-10 min |
| Setup | Flutter + Android SDK | Just push code |
| Cost | Free | Free (2000 min/month) |
| Convenience | Manual | Automatic |

## Next Steps

1. **Push your code** to GitHub
2. **Go to Actions tab** and run the workflow
3. **Download the APK** from Artifacts
4. **Send to your friend** for testing!

## Quick Commands

```bash
# Push code and trigger build
git add .
git commit -m "Update app"
git push

# Check build status
# Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/actions

# Download APK
# Go to: Actions → Latest run → Artifacts → app-release-apk
```

## Support

If the build fails:
1. Check the error logs in GitHub Actions
2. Fix the issue locally
3. Push the fix
4. The workflow will run again automatically

Happy building! 🚀
