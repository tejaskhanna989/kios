#!/bin/bash

# Rebuild APK with all fixes
set -e

echo "=== Rebuilding APK with All Fixes ==="

# Clean previous builds
rm -rf build app/build

# Create dummy libraries
mkdir -p app/src/main/jniLibs/arm64-v8a
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemuimg.so

# Build APK using gradle wrapper
echo "Building APK..."
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache 2>&1 | grep -E "(BUILD SUCCESSFUL|BUILD FAILED)"

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    
    # Copy to final location
    cp app/build/outputs/apk/debug/app-debug.apk kios-rebuilt-fixed.apk
    
    # Verify the APK
    echo "Verifying APK..."
    aapt dump badging kios-rebuilt-fixed.apk | grep -E "package|version"
    
    echo "✅ Rebuilt APK created: kios-rebuilt-fixed.apk"
    echo "Size: $(du -h kios-rebuilt-fixed.apk)"
    
    # Install on device if connected
    if adb devices | grep -q "device"; then
        echo "Installing on connected device..."
        adb -s 320081735bb166a3 install -r kios-rebuilt-fixed.apk
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
            adb -s 320081735bb166a3 shell "input tap 500 1000"  # Tap where Install iOS button would be
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
else
    echo "❌ APK build failed!"
    exit 1
fi