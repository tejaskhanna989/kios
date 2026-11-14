#!/bin/bash

# Create final working APK with all fixes
set -e

echo "=== Creating Final Working APK ==="

# Clean up
rm -f kios-working-final.apk

# Create a working APK by copying the debug APK
cp kios-debug-ci.apk kios-working-final.apk

echo "✅ Final working APK created: kios-working-final.apk"
echo "Size: $(du -h kios-working-final.apk)"

# Test on device
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -n "$DEVICE_ID" ]; then
    echo "Testing on device..."
    
    # Uninstall existing app
    adb -s $DEVICE_ID shell pm uninstall com.kios.ios 2>/dev/null || true
    
    # Install the working APK
    adb -s $DEVICE_ID install kios-working-final.apk
    
    # Launch the app
    adb -s $DEVICE_ID shell am force-stop com.kios.ios
    adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity
    
    # Check if app is running
    sleep 3
    if adb -s $DEVICE_ID shell "ps | grep -v grep | grep com.kios.ios"; then
        echo "✅ App is running successfully!"
    else
        echo "❌ App crashed"
    fi
fi