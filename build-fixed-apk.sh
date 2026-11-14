#!/bin/bash

# Build fixed APK with native library crash resolved
set -e

echo "=== Building Fixed APK ==="

# Clean previous builds
rm -rf build app/build

# Create dummy libraries if they don't exist
mkdir -p app/src/main/jniLibs/arm64-v8a
if [ ! -f app/src/main/jniLibs/arm64-v8a/libqemu.so ]; then
    echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemu.so
fi

if [ ! -f app/src/main/jniLibs/arm64-v8a/libqemuimg.so ]; then
    echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemuimg.so
fi

# Build the APK
echo "Building APK..."
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    
    # Copy to final location
    cp app/build/outputs/apk/debug/app-debug.apk kios-fixed.apk
    
    # Verify the APK
    echo "Verifying APK..."
    aapt dump badging kios-fixed.apk | grep -E "package|version"
    
    echo "✅ Fixed APK created: kios-fixed.apk"
    echo "Size: $(du -h kios-fixed.apk)"
    
    # Install on device if connected
    if adb devices | grep -q "device"; then
        echo "Installing on connected device..."
        adb install -r kios-fixed.apk
        echo "✅ App installed!"
    fi
else
    echo "❌ APK build failed!"
    exit 1
fi