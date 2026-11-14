#!/bin/bash

# Simple build script for Kios app with dummy libraries
set -e

echo "=== Building Kios App (Simple Version) ==="

# Clean previous builds
rm -rf build app/build

# Create dummy libraries if they don't exist
mkdir -p app/src/main/jniLibs/arm64-v8a
if [ ! -f app/src/main/jniLibs/arm64-v8a/libqemu.so ]; then
    echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemu.so
    echo "Created dummy libqemu.so"
fi

if [ ! -f app/src/main/jniLibs/arm64-v8a/libqemuimg.so ]; then
    echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemuimg.so
    echo "Created dummy libqemuimg.so"
fi

# Build the app
echo "Building APK..."
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    echo "APK location: app/build/outputs/apk/debug/app-debug.apk"
    
    # Install on device
    if adb devices | grep -q "device"; then
        echo "Installing on device..."
        adb install -r app/build/outputs/apk/debug/app-debug.apk
        echo "✅ App installed successfully!"
        
        # Launch the app
        echo "Launching app..."
        adb shell am force-stop com.kios.ios
        adb shell am start -n com.kios.ios/.MainActivity
        
        echo "✅ App launched! Check if it opens without crashing."
    else
        echo "❌ No device connected. Use 'adb devices' to check connection."
    fi
else
    echo "❌ APK build failed!"
    exit 1
fi