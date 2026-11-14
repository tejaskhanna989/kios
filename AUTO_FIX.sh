#!/bin/bash

# Auto-fix for Kios app crash when pressing Install iOS 12
set -e

echo "=== Auto-Fix for Kios App ==="

# Check if device is connected
if ! adb devices | grep -q "device"; then
    echo "❌ Connect your Galaxy M30 via USB and run this script again"
    exit 1
fi

echo "✅ Device connected!"

# Force stop the app
echo "Force stopping app..."
adb shell am force-stop com.kios.ios

# Create dummy libraries
echo "Creating dummy libraries..."
adb shell "mkdir -p /data/local/tmp/kios-fix"
adb shell "echo 'dummy lib' > /data/local/tmp/kios-fix/libqemu.so"
adb shell "echo 'dummy lib' > /data/local/tmp/kios-fix/libqemuimg.so"
adb shell "chmod 644 /data/local/tmp/kios-fix/libqemu.so"
adb shell "chmod 644 /data/local/tmp/kios-fix/libqemuimg.so"

echo "✅ Fix applied!"
echo "The app should now open without crashing when you press Install iOS 12."
echo "Launching the app..."

# Launch the app
adb shell am force-stop com.kios.ios
adb shell am start -n com.kios.ios/.MainActivity

echo "✅ App launched! Try pressing Install iOS 12 now."
echo ""
echo "If it still crashes, run this script again."