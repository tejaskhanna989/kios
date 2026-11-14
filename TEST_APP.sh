#!/bin/bash

# Test the Kios app
set -e

echo "=== Testing Kios App ==="

DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ No device connected!"
    exit 1
fi

echo "Device ID: $DEVICE_ID"

# Check if app is installed
if adb -s $DEVICE_ID shell pm list packages | grep -q "com.kios.ios"; then
    echo "✅ App is installed"
else
    echo "❌ App is not installed"
    adb -s $DEVICE_ID install kios-debug-ci.apk
fi

# Launch the app
echo "Launching app..."
adb -s $DEVICE_ID shell am force-stop com.kios.ios
adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity

# Wait and check if app is still running
sleep 5
if adb -s $DEVICE_ID shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "✅ App is running successfully!"
else
    echo "❌ App crashed"
    echo "Recent crash logs:"
    adb -s $DEVICE_ID logcat -d | grep -E "AndroidRuntime.*FATAL.*com.kios.ios" | tail -5
fi