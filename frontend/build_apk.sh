#!/bin/bash

echo "🏗️  UniLeague APK Builder"
echo "========================"
echo ""

# Check if we're in the frontend directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the frontend directory"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build APK
echo "🔨 Building release APK..."
echo "   This may take 5-10 minutes..."
flutter build apk --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📱 Your APK is ready at:"
    echo "   $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "📊 File size:"
    ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print "   " $5}'
    echo ""
    echo "📤 Next steps:"
    echo "   1. Send the APK to your friend"
    echo "   2. They need to enable 'Install from Unknown Sources'"
    echo "   3. Install and test!"
    echo ""
else
    echo ""
    echo "❌ Build failed!"
    echo "   Check the error messages above"
    exit 1
fi
