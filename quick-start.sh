#!/bin/bash

# Quick start script for testing Kios on your M30
# Run this on your PC after downloading the APK to your phone

echo "=== Kios Quick Start for Galaxy M30 ==="
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "ERROR: ADB not found. Install Android Platform Tools first."
    exit 1
fi

# Check if phone is connected
echo "Checking if phone is connected..."
adb devices | grep -v "List" | grep -v "offline" | grep -v "unauthorized" | grep -v "^$" | head -5

if [ $? -ne 0 ]; then
    echo "ERROR: No Android device found via ADB."
    echo "1. Enable USB debugging on your M30"
    echo "2. Connect via USB"
    echo "3. Allow the computer connection when prompted"
    exit 1
fi

echo "Phone connected successfully!"
echo ""

# Download APK if not present
if [ ! -f "kios-debug.apk" ]; then
    echo "Downloading latest APK..."
    curl -L -o kios-debug.apk \
      "https://api.github.com/repos/tejaskhanna989/kios/actions/artifacts/14056454919/zip" \
      -H "Accept: application/vnd.github.v3+json"
    
    if [ ! -f "kios-debug.apk" ]; then
        echo "ERROR: Failed to download APK!"
        exit 1
    fi
    
    echo "APK downloaded: kios-debug.apk"
fi

# Install APK
echo "Installing Kios on your M30..."
adb install kios-debug.apk

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Kios installed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Open Kios app on your M30"
    echo "2. Follow the TESTING_GUIDE.md for iOS 12 setup"
    echo "3. Run extract-ios12.sh on your PC first"
    echo ""
    echo "Good luck with testing! 🍎"
else
    echo "❌ Installation failed!"
    echo "Check phone connection and try again."
    exit 1
fi