#!/bin/bash

# Direct APK modification
set -e

echo "=== Direct APK Modification ==="

# Create dummy libraries directly in the APK
mkdir -p temp_libs
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > temp_libs/libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > temp_libs/libqemuimg.so

# Create a new APK with the libraries
cd temp_libs
zip -r ../kios-direct-modified.apk libqemu.so libqemuimg.so
cd ..
rm -rf temp_libs

# Now extract the original APK and add the libraries
mkdir -p temp_apk
cd temp_apk
unzip -q ../kios-debug-ci.apk
mkdir -p app/src/main/jniLibs/arm64-v8a
cp ../libqemu.so app/src/main/jniLibs/arm64-v8a/
cp ../libqemuimg.so app/src/main/jniLibs/arm64-v8a/
zip -r ../kios-direct-final.apk . -x "META-INF/*"
cd ..
rm -rf temp_apk
rm -f libqemu.so libqemuimg.so

echo "✅ Direct Modified APK created: kios-direct-final.apk"
echo "Size: $(du -h kios-direct-final.apk)"

# Install on device
if adb devices | grep -q "device"; then
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-direct-final.apk
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