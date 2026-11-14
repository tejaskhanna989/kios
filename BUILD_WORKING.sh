#!/bin/bash

# Build working APK
set -e

echo "=== Building Working APK ==="

# The issue is that the native library is missing the alive method.
# We need to fix this by creating a proper APK with the fixed source code.

# Let's try to build the APK with the fixes
echo "Building APK with fixes..."

# Clean previous builds
rm -rf build app/build

# Build the APK
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache 2>&1 | tail -20

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    
    # Copy to final location
    cp app/build/outputs/apk/debug/app-debug.apk kios-built.apk
    
    # Verify the APK
    echo "Verifying APK..."
    aapt dump badging kios-built.apk | grep -E "package|version"
    
    echo "✅ Built APK created: kios-built.apk"
    echo "Size: $(du -h kios-built.apk)"
    
    # Install on device
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-built.apk
    
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
            
            echo "✅ Built APK successful!"
        else
            echo "❌ App crashed when clicking"
        fi
    else
        echo "❌ App crashed on launch"
    fi
else
    echo "❌ APK build failed!"
    exit 1
fi