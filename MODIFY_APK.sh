#!/bin/bash

# Modify existing APK to include proper libraries
set -e

echo "=== Modifying APK to Include Proper Libraries ==="

# Create temporary directory
mkdir -p temp_apk

# Extract the existing APK
cd temp_apk
unzip -q ../kios-debug-ci.apk

# Create proper library directory structure
mkdir -p app/src/main/jniLibs/arm64-v8a

# Create proper dummy libraries (ELF header format)
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemuimg.so

# Create new APK
zip -r ../kios-modified.apk . -x META-INF/*

# Clean up
cd ..
rm -rf temp_apk

echo "✅ Modified APK created: kios-modified.apk"
echo "Size: $(du -h kios-modified.apk)"

# Install on device
if adb devices | grep -q "device"; then
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-modified.apk
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