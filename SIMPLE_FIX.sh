#!/bin/bash

# Simple fix for Kios app crash
set -e

echo "=== Simple Fix for Kios App ==="

# Check if device is connected
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ No device connected!"
    exit 1
fi

echo "Device ID: $DEVICE_ID"

# Force stop the app
echo "Force stopping app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios

# Uninstall the current app
echo "Uninstalling current app..."
adb -s $DEVICE_ID shell pm uninstall com.kios.ios

# Create dummy libraries
echo "Creating dummy libraries..."
adb -s $DEVICE_ID shell "mkdir -p /sdcard/Download/libs"
adb -s $DEVICE_ID shell "echo 'dummy lib' > /sdcard/Download/libs/libqemu.so"
adb -s $DEVICE_ID shell "echo 'dummy lib' > /sdcard/Download/libs/libqemuimg.so"
adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemu.so"
adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemuimg.so"

# Install the original APK
echo "Installing original APK..."
adb -s $DEVICE_ID install kios-debug-ci.apk

# Launch the app
echo "Launching app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios
adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched! Try clicking again."