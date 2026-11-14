#!/bin/bash

# Simple working solution
set -e

echo "=== Simple Working Solution ==="

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

# Install the original APK
echo "Installing original APK..."
adb -s $DEVICE_ID install kios-debug-ci.apk

# Create dummy libraries in accessible location
echo "Creating dummy libraries..."
adb -s $DEVICE_ID shell "mkdir -p /sdcard/Download/libs"
adb -s $DEVICE_ID shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemu.so"
adb -s $DEVICE_ID shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemuimg.so"
adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemu.so"
adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemuimg.so"

# Launch the app
echo "Launching app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios
adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched! Check if it's working..."
sleep 3

if adb -s $DEVICE_ID shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "✅ App is running successfully!"
else
    echo "❌ App crashed"
fi