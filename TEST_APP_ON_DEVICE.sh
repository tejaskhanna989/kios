#!/bin/bash

echo "=== Testing Kios App on Device ==="

# Check if device is connected
if ! adb devices | grep -q "320081735bb166a3"; then
    echo "❌ Device not connected!"
    exit 1
fi

echo "✅ Device connected: 320081735bb166a3"

# Check if app is installed
if ! adb shell pm list packages | grep -q "com.kios.ios"; then
    echo "❌ Kios app not installed!"
    echo "Installing app..."
    adb install -r kios-ci-working.apk
    
    if [ $? -eq 0 ]; then
        echo "✅ App installed successfully"
    else
        echo "❌ Failed to install app"
        exit 1
    fi
else
    echo "✅ Kios app is already installed"
fi

# Start the app
echo "Starting Kios app..."
adb shell am start -n com.kios.ios/.MainActivity

# Wait a moment for app to load
sleep 3

# Check if app is running
if adb shell dumpsys activity top | grep -q "com.kios.ios"; then
    echo "✅ App is running successfully"
    
    # Check for any recent errors in logs
    echo "Checking for recent errors..."
    RECENT_ERRORS=$(adb logcat -d | grep -i "error\|exception\|crash" | grep kios | tail -5)
    
    if [ -n "$RECENT_ERRORS" ]; then
        echo "⚠️  Some recent errors found:"
        echo "$RECENT_ERRORS"
    else
        echo "✅ No recent errors found"
    fi
    
    # Test the "Install iOS" functionality
    echo ""
    echo "📱 Manual Testing Instructions:"
    echo "1. Open the Kios app on your device"
    echo "2. Tap the 'Install iOS' button"
    echo "3. Verify that iOS 12.4.1 starts downloading"
    echo "4. Check that the installation process completes"
    echo "5. Confirm that you reach the iOS lock screen"
    
else
    echo "❌ App may not be running properly"
    echo "Check device logs:"
    adb logcat -d | grep -i kios | tail -10
fi

echo ""
echo "🎯 Next Steps:"
echo "- Open the Kios app on your device"
echo "- Test the 'Install iOS' functionality"
echo "- Verify iOS 12.4.1 downloads and installs correctly"
echo "- Check that you reach the iOS lock screen without crashes"