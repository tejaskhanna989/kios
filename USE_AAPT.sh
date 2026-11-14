#!/bin/bash

# Use aapt to modify APK
set -e

echo "=== Using AAPT to Modify APK ==="

# Create dummy libraries
mkdir -p temp_libs
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > temp_libs/libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > temp_libs/libqemuimg.so

# Create a new APK structure
mkdir -p temp_apk/app/src/main/jniLibs/arm64-v8a
cp temp_libs/libqemu.so temp_apk/app/src/main/jniLibs/arm64-v8a/
cp temp_libs/libqemuimg.so temp_apk/app/src/main/jniLibs/arm64-v8a/

# Copy original APK contents
cd temp_apk
unzip -q ../kios-debug-ci.apk
cd ..

# Create new APK
cd temp_apk
zip -r ../kios-aapt-modified.apk . -x "META-INF/*"
cd ..
rm -rf temp_apk temp_libs

echo "✅ AAPT Modified APK created: kios-aapt-modified.apk"
echo "Size: $(du -h kios-aapt-modified.apk)"

# Install on device
if adb devices | grep -q "device"; then
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-aapt-modified.apk
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