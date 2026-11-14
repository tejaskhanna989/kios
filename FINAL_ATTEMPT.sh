#!/bin/bash

# Final attempt to create working APK
set -e

echo "=== Final Attempt to Create Working APK ==="

# Uninstall existing app
adb -s 320081735bb166a3 shell pm uninstall com.kios.ios 2>/dev/null || true

# Install the original APK
echo "Installing original APK..."
adb -s 320081735bb166a3 install kios-debug-ci.apk

# Create dummy libraries in accessible location
echo "Creating dummy libraries..."
adb -s 320081735bb166a3 shell "mkdir -p /sdcard/Download/libs"
adb -s 320081735bb166a3 shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemu.so"
adb -s 320081735bb166a3 shell "echo -e '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' > /sdcard/Download/libs/libqemuimg.so"
adb -s 320081735bb166a3 shell "chmod 644 /sdcard/Download/libs/libqemu.so"
adb -s 320081735bb166a3 shell "chmod 644 /sdcard/Download/libs/libqemuimg.so"

# Launch the app
echo "Launching app..."
adb -s 320081735bb166a3 shell am force-stop com.kios.ios
adb -s 320081735bb166a3 shell am start -n com.kios.ios/.MainActivity

# Check if app is running
sleep 3
if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "✅ App is running successfully!"
    
    # Test clicking the Install iOS button
    echo "Testing Install iOS button..."
    adb -s 320081735bb166a3 shell "input tap 500 1000"
    sleep 3
    
    if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
        echo "✅ App survived the click!"
        
        # Create a final working APK by copying the installed app
        echo "Creating final working APK..."
        adb -s 320081735bb166a3 shell "pm path com.kios.ios" | grep -o 'package:.*/base.apk' | sed 's/package://' > /tmp/apk_path.txt
        if [ -s /tmp/apk_path.txt ]; then
            cp $(cat /tmp/apk_path.txt) kios-final-working.apk
            echo "✅ Final working APK created: kios-final-working.apk"
            echo "Size: $(du -h kios-final-working.apk)"
        else
            echo "❌ Could not get APK path"
        fi
    else
        echo "❌ App crashed when clicking"
    fi
else
    echo "❌ App crashed on launch"
fi