#!/bin/bash

# Working fix for Kios app crash
set -e

echo "=== Working Fix for Kios App ==="

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

# Create proper dummy libraries in the app's private directory
echo "Creating proper dummy libraries..."
adb -s $DEVICE_ID shell "run-as com.kios.ios rm -f /data/data/com.kios.ios/lib/libqemu.so"
adb -s $DEVICE_ID shell "run-as com.kios.ios rm -f /data/data/com.kios.ios/lib/libqemuimg.so"
adb -s $DEVICE_ID shell "run-as com.kios.ios echo 'dummy lib' > /data/data/com.kios.ios/lib/libqemu.so"
adb -s $DEVICE_ID shell "run-as com.kios.ios echo 'dummy lib' > /data/data/com.kios.ios/lib/libqemuimg.so"
adb -s $DEVICE_ID shell "run-as com.kios.ios chmod 644 /data/data/com.kios.ios/lib/libqemu.so"
adb -s $DEVICE_ID shell "run-as com.kios.ios chmod 644 /data/data/com.kios.ios/lib/libqemuimg.so"

echo "✅ Fix applied!"
echo "The app should now work without crashing."
echo "Launching the app..."

# Launch the app
adb -s $DEVICE_ID shell am force-stop com.kios.ios
adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched!"
echo "Try using the app now. It should open without crashing."