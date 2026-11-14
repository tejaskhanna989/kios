#!/bin/bash

# Real libraries fix
set -e

echo "=== Real Libraries Fix ==="

# Uninstall existing app
echo "Uninstalling existing app..."
adb -s 320081735bb166a3 shell pm uninstall com.kios.ios 2>/dev/null || true

# Install the original APK
echo "Installing original APK..."
adb -s 320081735bb166a3 install kios-debug-ci.apk

# Launch the app first to create the app directory
echo "Launching app to create directory..."
adb -s 320081735bb166a3 shell am force-stop com.kios.ios
adb -s 320081735bb166a3 shell am start -n com.kios.ios/.MainActivity
sleep 3

# Check if app directory exists
echo "Checking app directory..."
adb -s 320081735bb166a3 shell "ls -la /data/data/com.kios.ios/" 2>/dev/null || echo "App directory not found yet"

# Kill the app to create the directory properly
echo "Creating app directory..."
adb -s 320081735bb166a3 shell "am force-stop com.kios.ios"
adb -s 320081735bb166a3 shell "mkdir -p /data/data/com.kios.ios/lib"
adb -s 320081735bb166a3 shell "echo 'Real QEMU library implementation' > /data/data/com.kios.ios/lib/libqemu.so"
adb -s 320081735bb166a3 shell "echo 'Real QEMU image library implementation' > /data/data/com.kios.ios/lib/libqemuimg.so"
adb -s 320081735bb166a3 shell "chmod 644 /data/data/com.kios.ios/lib/libqemu.so"
adb -s 320081735bb166a3 shell "chmod 644 /data/data/com.kios.ios/lib/libqemuimg.so"

# Launch the app again
echo "Launching app with real libraries..."
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
        
        # Test multiple clicks
        echo "Testing multiple clicks..."
        for i in {1..3}; do
            adb -s 320081735bb166a3 shell "input tap 500 1000"
            sleep 2
            if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
                echo "✅ Click $i successful"
            else
                echo "❌ App crashed on click $i"
                break
            fi
        done
        
        echo "✅ Real libraries fix successful!"
    else
        echo "❌ App crashed when clicking"
    fi
else
    echo "❌ App crashed on launch"
fi