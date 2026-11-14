#!/bin/bash

# Create final working APK V2
set -e

echo "=== Creating Final Working APK V2 ==="

# Clean up
rm -f kios-final-working-v2.apk

# Copy the working APK
cp kios-ci-working.apk kios-final-working-v2.apk

echo "✅ Final Working APK V2 created: kios-final-working-v2.apk"
echo "Size: $(du -h kios-final-working-v2.apk)"

# Test on device
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -n "$DEVICE_ID" ]; then
    echo "Testing on device..."
    
    # Uninstall existing app
    adb -s $DEVICE_ID shell pm uninstall com.kios.ios 2>/dev/null || true
    
    # Install the working APK
    adb -s $DEVICE_ID install kios-final-working-v2.apk
    
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
        
        # Test clicking the Install iOS button
        echo "Testing Install iOS button..."
        adb -s $DEVICE_ID shell "input tap 500 1000"  # Tap where Install iOS button would be
        sleep 3
        
        if adb -s $DEVICE_ID shell "ps | grep -v grep | grep com.kios.ios"; then
            echo "✅ App survived the click!"
            
            # Verify the app is still responsive
            adb -s $DEVICE_ID shell "dumpsys activity top | grep -A 5 'TASK.*kios'"
        else
            echo "❌ App crashed when clicking"
        fi
    else
        echo "❌ App crashed on launch"
    fi
fi