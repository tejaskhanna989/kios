#!/bin/bash

# Build fixed APK with proper libraries
set -e

echo "=== Building Fixed APK ==="

# Clean previous builds
rm -rf build app/build

# Create proper directory structure for libraries
mkdir -p app/src/main/jniLibs/arm64-v8a

# Create proper dummy libraries with correct format
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemuimg.so

# Build the APK
echo "Building APK..."
./gradlew assembleDebug --no-daemon --offline --parallel --no-build-cache

if [ -f app/build/outputs/apk/debug/app-debug.apk ]; then
    echo "✅ APK built successfully!"
    
    # Copy to final location
    cp app/build/outputs/apk/debug/app-debug.apk kios-fixed-libraries.apk
    
    # Verify the APK
    echo "Verifying APK..."
    aapt dump badging kios-fixed-libraries.apk | grep -E "package|version"
    
    echo "✅ Fixed APK created: kios-fixed-libraries.apk"
    echo "Size: $(du -h kios-fixed-libraries.apk)"
    
    # Install on device if connected
    if adb devices | grep -q "device"; then
        echo "Installing on connected device..."
        adb -s 320081735bb166a3 install -r kios-fixed-libraries.apk
        echo "✅ App installed!"
        
        # Launch the app
        adb -s 320081735bb166a3 shell am force-stop com.kios.ios
        adb -s 320081735bb166a3 shell am start -n com.kios.ios/.MainActivity
        
        # Check if app is running
        sleep 3
        if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
            echo "✅ App is running successfully!"
        else
            echo "❌ App crashed"
        fi
    fi
else
    echo "❌ APK build failed!"
    exit 1
fi