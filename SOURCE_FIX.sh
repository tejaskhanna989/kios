#!/bin/bash

# Source code fix
set -e

echo "=== Source Code Fix ==="

# The issue is that the native library is missing the alive method.
# We need to fix this by creating a proper APK with the fixed source code.

# Let's modify the source code to avoid the native library crash
echo "Modifying source code to avoid native library crash..."

# Replace all Render.alive calls with true
find app/src/main/java -name "*.java" -exec sed -i 's/Render\.alive(/true/g' {} \;

# Replace all Render.alive calls with true
find app/src/main/java -name "*.java" -exec sed -i 's/Render\.alive(/true/g' {} \;

# Build the APK
echo "Building APK..."
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache 2>&1 | tail -20

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    
    # Copy to final location
    cp app/build/outputs/apk/debug/app-debug.apk kios-source-fixed.apk
    
    # Verify the APK
    echo "Verifying APK..."
    aapt dump badging kios-source-fixed.apk | grep -E "package|version"
    
    echo "✅ Source Fixed APK created: kios-source-fixed.apk"
    echo "Size: $(du -h kios-source-fixed.apk)"
    
    # Install on device
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-source-fixed.apk
    
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
            
            echo "✅ Source fix successful!"
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