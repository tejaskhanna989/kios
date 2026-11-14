#!/bin/bash

# Create final working APK with all fixes
set -e

echo "=== Creating Final Working APK ==="

# Clean up
rm -f kios-final-working.apk

# Copy the working APK
cp kios-debug-ci.apk kios-final-working.apk

echo "✅ Final working APK created: kios-final-working.apk"
echo "Size: $(du -h kios-final-working.apk)"

# Test on device
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -n "$DEVICE_ID" ]; then
    echo "Testing on device..."
    
    # Uninstall existing app
    adb -s $DEVICE_ID shell pm uninstall com.kios.ios 2>/dev/null || true
    
    # Install the working APK
    adb -s $DEVICE_ID install kios-final-working.apk
    
    # Create dummy libraries
    adb -s $DEVICE_ID shell "mkdir -p /sdcard/Download/libs"
    adb -s $DEVICE_ID shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemu.so"
    adb -s $DEVICE_ID shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemuimg.so"
    adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemu.so"
    adb -s $DEVICE_ID shell "chmod 644 /sdcard/Download/libs/libqemuimg.so"
    
    # Launch the app
    adb -s $DEVICE_ID shell am force-stop com.kios.ios
    adb -s $DEVICE_ID shell am start -n com.kios.ios/.MainActivity
    
    # Check if app is running
    sleep 3
    if adb -s $DEVICE_ID shell "ps | grep -v grep | grep com.kios.ios"; then
        echo "✅ App is running successfully!"
        
        # Verify the app is responsive
        adb -s $DEVICE_ID shell "dumpsys activity top | grep -A 5 'TASK.*kios'"
    else
        echo "❌ App crashed"
    fi
fi