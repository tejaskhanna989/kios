#!/bin/bash

# Simple test to understand the native library issue
set -e

echo "=== Simple Test ==="

# First, let's get the current app state
echo "Getting current app state..."
adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"

# Let's try to click the button and see what happens
echo "Clicking the Install iOS button..."
adb -s 320081735bb166a3 shell "input tap 500 1000"

# Wait a bit and check if the app is still running
sleep 3
if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "✅ App is still running after click"
    
    # Try clicking again
    echo "Clicking again..."
    adb -s 320081735bb166a3 shell "input tap 500 1000"
    sleep 3
    
    if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
        echo "✅ App is still running after second click"
        
        # Try clicking a third time
        echo "Clicking a third time..."
        adb -s 320081735bb166a3 shell "input tap 500 1000"
        sleep 3
        
        if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
            echo "✅ App is still running after third click"
            echo "✅ Test successful - app seems to be working!"
        else
            echo "❌ App crashed on third click"
        fi
    else
        echo "❌ App crashed on second click"
    fi
else
    echo "❌ App crashed on first click"
fi

# Let's get the crash logs if the app crashed
if ! adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
    echo "Getting crash logs..."
    adb -s 320081735bb166a3 logcat -d | grep -E "(FATAL|AndroidRuntime|E/AndroidRuntime|E/CrashReport)" | tail -5
fi