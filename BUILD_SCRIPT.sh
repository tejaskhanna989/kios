#!/bin/bash

# Build script for Kios - iOS 12 for Android
# Run this to build the APK for testing on your M30

echo "=== Building Kios APK ==="
echo ""

# Check if we're in the right directory
if [ ! -f "app/build.gradle" ]; then
    echo "ERROR: Not in the Kios project directory!"
    echo "Please run this script from the kios folder."
    exit 1
fi

# Check if Android SDK is available
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "WARNING: ANDROID_HOME/ANDROID_SDK_ROOT not set"
    echo "Make sure Android SDK is installed and configured"
    echo ""
fi

# Clean previous builds
echo "Cleaning previous builds..."
./gradlew clean

# Build debug APK
echo ""
echo "Building debug APK..."
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "APK location: app/build/outputs/apk/debug/app-debug.apk"
    echo ""
    echo "To install on your M30:"
    echo "1. Enable USB debugging on your phone"
    echo "2. Connect phone to PC"
    echo "3. Run: adb install app/build/outputs/apk/debug/app-debug.apk"
    echo ""
    echo "Then follow the TESTING_GUIDE.md for iOS 12 setup"
else
    echo "❌ Build failed!"
    echo "Check the error messages above and fix any issues."
    exit 1
fi