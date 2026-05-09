# Quick Start: Build APK with GitHub Actions

## 🎯 Goal
Build your Android APK in the cloud (no local disk space needed!)

## ⚡ Quick Steps

### 1️⃣ Run Setup Script
```bash
./setup_github_build.sh
```

### 2️⃣ Push to GitHub
```bash
git push -u origin main
```
(Use `master` instead of `main` if that's your branch name)

### 3️⃣ Go to GitHub Actions
Open in browser:
```
https://github.com/YOUR_USERNAME/YOUR_REPO/actions
```

### 4️⃣ Run the Workflow
1. Click **"Build Android APK"** (left sidebar)
2. Click **"Run workflow"** (top right)
3. Click green **"Run workflow"** button
4. Wait 5-10 minutes ⏱️

### 5️⃣ Download APK
1. Click on the completed workflow (green ✅)
2. Scroll to **"Artifacts"**
3. Click **"app-release-apk"**
4. Extract ZIP → Get `app-release.apk`

### 6️⃣ Send to Friend
- Email the APK
- Or upload to Google Drive/Dropbox
- Friend installs on Android phone

## 📱 Installation on Phone

Your friend needs to:
1. Enable "Install from Unknown Sources"
2. Download the APK
3. Tap to install
4. Open "UniLeague" app

## 🔄 Update the App

When you make changes:
```bash
git add .
git commit -m "Your changes"
git push
```

The APK will rebuild automatically! ✨

## ❓ Troubleshooting

**Don't have a GitHub account?**
1. Go to https://github.com
2. Sign up (free)
3. Create new repository
4. Use that URL in setup script

**Build failed?**
1. Go to Actions tab
2. Click failed run
3. Check error logs
4. Fix the issue
5. Push again

**Can't find Artifacts?**
- Make sure build has green ✅
- Scroll to bottom of workflow run page
- Look for "Artifacts" section

## 💡 Pro Tips

- **Automatic builds**: Every push to main/master triggers a build
- **Manual builds**: Use "Run workflow" button anytime
- **Free tier**: 2000 minutes/month (200+ builds)
- **Build time**: ~5-10 minutes per build

## 📊 What You Get

- **app-release.apk** (~30-50 MB)
- Works on all Android devices
- Ready to install and test

## 🎉 That's It!

No more disk space issues. No more Gradle problems. Just push and download! 🚀
