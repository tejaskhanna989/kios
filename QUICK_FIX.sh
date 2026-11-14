#!/bin/bash

# Quick fix for Kios app crash
set -e

echo "=== Quick Fix for Kios App ==="

# Check if device is connected
if ! adb devices | grep -q "device"; then
    echo "❌ Connect your device via USB!"
    exit 1
fi

# Force stop the app
echo "Force stopping app..."
adb shell am force-stop com.kios.ios

# Create dummy libraries
echo "Creating dummy libraries..."
adb shell "mkdir -p /sdcard/Download/libs"
adb shell "echo 'dummy lib' > /sdcard/Download/libs/libqemu.so"
adb shell "echo 'dummy lib' > /sdcard/Download/libs/libqemuimg.so"
adb shell "chmod 644 /sdcard/Download/libs/libqemu.so"
adb shell "chmod 644 /sdcard/Download/libs/libqemuimg.so"

# Install the original APK
echo "Installing original APK..."
adb install kios-debug-ci.apk

# Launch the app
echo "Launching app..."
adb shell am force-stop com.kios.ios
adb shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched! Try clicking again."