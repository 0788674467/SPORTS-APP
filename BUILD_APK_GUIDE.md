# Build APK for Testing

## Quick Build Command

Run this command from the `frontend` directory:

```bash
flutter build apk --release
```

The APK will be created at:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Step-by-Step Instructions

### 1. Check Flutter Setup
```bash
cd frontend
flutter doctor
```

Make sure Android toolchain is installed. If not, run:
```bash
flutter doctor --android-licenses
```

### 2. Clean Previous Builds
```bash
flutter clean
flutter pub get
```

### 3. Build the APK

**Option A: Single APK (Larger file, works on all devices)**
```bash
flutter build apk --release
```

**Option B: Split APKs (Smaller files, one per architecture)**
```bash
flutter build apk --split-per-abi --release
```

This creates 3 APKs:
- `app-armeabi-v7a-release.apk` (32-bit ARM - older phones)
- `app-arm64-v8a-release.apk` (64-bit ARM - most modern phones)
- `app-x86_64-release.apk` (Intel processors - rare)

**Recommended**: Use the single APK for testing, or send the `arm64-v8a` version for modern phones.

### 4. Find Your APK

After building, the APK will be at:
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

Or if you used split APKs:
```
frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
frontend/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
frontend/build/app/outputs/flutter-apk/app-x86_64-release.apk
```

### 5. Send to Your Friend

**Via Email/WhatsApp:**
- Attach the APK file
- File size will be ~20-50 MB

**Via Google Drive/Dropbox:**
- Upload the APK
- Share the link

**Via ADB (if phone is connected):**
```bash
flutter install
```

## Installation on Phone

Your friend needs to:

1. **Enable Unknown Sources**:
   - Go to Settings → Security
   - Enable "Install from Unknown Sources" or "Install Unknown Apps"
   - Allow installation from the browser/file manager

2. **Install the APK**:
   - Download the APK file
   - Tap on it to install
   - Accept permissions

3. **Open the App**:
   - Find "UniLeague" in the app drawer
   - Open and test!

## Testing Without Internet

The app currently requires internet for:
- Login/Authentication (Supabase)
- Loading data (teams, players, matches)
- Real-time updates

**Note**: The offline functionality we implemented earlier was reverted due to disk space issues. To test offline:

1. **Login with internet first**
2. **Load all data** (visit all pages)
3. **Turn off internet**
4. **Test the app** - some cached data may still work

## Troubleshooting

### Error: "Android SDK not found"
```bash
flutter config --android-sdk /path/to/android/sdk
```

### Error: "Gradle build failed"
Check `frontend/android/app/build.gradle` and ensure:
- `minSdkVersion` is at least 21
- `targetSdkVersion` is 33 or higher

### Error: "Execution failed for task ':app:lintVitalRelease'"
Add this to `frontend/android/app/build.gradle`:
```gradle
android {
    lintOptions {
        checkReleaseBuilds false
    }
}
```

### APK is too large
Use split APKs:
```bash
flutter build apk --split-per-abi --release
```

## Build Configuration

### App Name
Edit `frontend/android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="UniLeague"
    ...>
```

### App Icon
Replace icons in:
```
frontend/android/app/src/main/res/mipmap-*/ic_launcher.png
```

### Version
Edit `frontend/pubspec.yaml`:
```yaml
version: 1.0.0+1
```

Format: `major.minor.patch+buildNumber`

## Quick Build Script

Create `frontend/build_apk.sh`:
```bash
#!/bin/bash
echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building APK..."
flutter build apk --release

echo "✅ Build complete!"
echo "📱 APK location:"
echo "   $(pwd)/build/app/outputs/flutter-apk/app-release.apk"

# Open the folder
open build/app/outputs/flutter-apk/ 2>/dev/null || \
xdg-open build/app/outputs/flutter-apk/ 2>/dev/null || \
echo "   Please navigate to the folder above to find your APK"
```

Make it executable:
```bash
chmod +x build_apk.sh
./build_apk.sh
```

## Expected Build Time

- First build: 5-10 minutes
- Subsequent builds: 2-5 minutes

## File Size

- Single APK: ~30-50 MB
- Split APK (arm64): ~20-30 MB

## Testing Checklist

Send this to your friend:

- [ ] Install APK successfully
- [ ] Open app without crashes
- [ ] Login as referee/coach/admin
- [ ] Navigate through all pages
- [ ] Upload profile picture
- [ ] Check if picture shows in sidebar
- [ ] Test with internet ON
- [ ] Test with internet OFF (limited functionality)
- [ ] Check for any crashes or errors

## Next Steps

After your friend tests:
1. Collect feedback
2. Fix any issues
3. Rebuild and resend
4. When ready, publish to Google Play Store
