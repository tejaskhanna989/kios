#!/bin/bash

echo "=== Checking Android Device Connection ==="

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found. Please install Android Debug Bridge."
    exit 1
fi

# Check if device is connected
echo "Checking for connected devices..."
adb devices

# Get device count
DEVICE_COUNT=$(adb devices | grep -v "List of devices attached" | grep -v "^$" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android device connected."
    echo ""
    echo "To connect your device:"
    echo "1. Enable Developer options on your Android device"
    echo "2. Enable USB debugging in Developer options"
    echo "3. Connect your device via USB"
    echo "4. Check if your computer recognizes the device"
    exit 1
else
    echo "✅ Android device connected!"
    
    # Get device model
    DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
    DEVICE_MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr -d '\r')
    
    echo "Device: $DEVICE_MANUFACTURER $DEVICE_MODEL"
    
    # Check if app is already installed
    if adb shell pm list packages | grep -q "com.kios.ios"; then
        echo "✅ Kios app is already installed"
        echo "To test the app:"
        echo "1. Open the Kios app on your device"
        echo "2. Tap 'Install iOS' to test iOS 12 installation"
    else
        echo "📱 Kios app not installed. Ready to install test APK."
        echo "To install the test APK:"
        echo "adb install -r kios-test-fixed.apk"
    fi
    
    # Check storage space
    echo ""
    echo "Checking device storage..."
    STORAGE_INFO=$(adb shell df /data | tail -1 | awk '{print $4" "$5}')
    STORAGE_AVAILABLE=$(echo $STORAGE_INFO | awk '{print $1}')
    STORAGE_USED=$(echo $STORAGE_INFO | awk '{print $2}')
    
    echo "Storage: Available: ${STORAGE_AVAILABLE}KB, Used: ${STORAGE_USED}%"
    
    # Check if we have enough space for APK
    APK_SIZE=$(stat -c%s kios-test-fixed.apk 2>/dev/null || echo "0")
    if [ "$APK_SIZE" -gt 0 ]; then
        APK_SIZE_KB=$((APK_SIZE / 1024))
        echo "APK size: ${APK_SIZE_KB}KB"
        
        # Check if we have enough space (need at least 1.5x APK size)
        REQUIRED_SPACE=$((APK_SIZE_KB * 3 / 2))
        STORAGE_AVAILABLE_KB=$((STORAGE_AVAILABLE / 1024))
        
        if [ "$STORAGE_AVAILABLE_KB" -lt "$REQUIRED_SPACE" ]; then
            echo "⚠️  Warning: May not have enough storage space"
            echo "Required: ~${REQUIRED_SPACE}KB, Available: ${STORAGE_AVAILABLE_KB}KB"
        else
            echo "✅ Sufficient storage space available"
        fi
    fi
fi

echo ""
echo "Next steps:"
echo "1. If device is connected, install the test APK:"
echo "   adb install -r kios-test-fixed.apk"
echo "2. Open Kios app and test iOS 12 installation"
echo "3. Check app logs for any errors:"
echo "   adb logcat | grep -i kios"