#!/bin/bash

# Test native library issue
set -e

echo "=== Testing Native Library Issue ==="

# Install the app
echo "Installing app..."
adb -s 320081735bb166a3 install -r kios-simple-working.apk

# Launch the app
echo "Launching app..."
adb -s 320081735bb166a3 shell am force-stop com.kios.ios
adb -s 320081735bb166a3 shell am start -n com.kios.ios/.MainActivity

# Check if app is running
sleep 3
if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "✅ App is running"
    
    # Check the native libraries
    echo "Checking native libraries..."
    adb -s 320081735bb166a3 shell "ls -la /data/app/~~VYkfgZZ-h8TbCRE-837tMQ==/com.kios.ios-8PRuDlQanpY8LkxIcRFMYQ==/lib/arm64-v8a/"
    
    # Try to click the button
    echo "Trying to click..."
    adb -s 320081735bb166a3 shell "input tap 500 1000"
    sleep 3
    
    # Check if app is still running
    if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
        echo "✅ App survived"
    else
        echo "❌ App crashed"
        
        # Check for crash logs
        echo "Checking crash logs..."
        adb -s 320081735bb166a3 logcat -d | grep -E "AndroidRuntime.*FATAL" | tail -5
    fi
else
    echo "❌ App not running"
fi