#!/bin/bash

# Simple fix for device
set -e

echo "=== Simple Fix for Kios App ==="

DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ No device connected!"
    exit 1
fi

echo "Device ID: $DEVICE_ID"

# Force stop the app
echo "Force stopping app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios

# Uninstall the app
echo "Uninstalling app..."
adb -s $DEVICE_ID shell pm uninstall com.kios.ios

# Install the APK
echo "Installing APK..."
adb -s $DEVICE_ID install kios-debug-ci.apk

# Launch the app
echo "Launching app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios
adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched! Try clicking now."