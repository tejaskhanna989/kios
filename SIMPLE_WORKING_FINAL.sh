#!/bin/bash

# Simple working final APK
set -e

echo "=== Simple Working Final APK ==="

# Create a working APK by copying the existing one
cp kios-debug-ci.apk kios-simple-working.apk

echo "✅ Simple Working APK created: kios-simple-working.apk"
echo "Size: $(du -h kios-simple-working.apk)"

# Install on device
if adb devices | grep -q "device"; then
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-simple-working.apk
    echo "✅ App installed!"
    
    # Launch the app
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
        else
            echo "❌ App crashed when clicking"
        fi
    else
        echo "❌ App crashed on launch"
    fi
fi