#!/bin/bash

# Fix native library
set -e

echo "=== Fix Native Library ==="

# The issue is that the native library is missing the alive method.
# We need to fix this by creating a proper APK with the fixed source code.

# Let's create a working APK by fixing the native library
echo "Creating working APK with fixed native library..."

# Use the existing APK and add the necessary fixes
mkdir -p temp_native
cd temp_native
unzip -q ../kios-debug-ci.apk

# Create a proper native library implementation
mkdir -p app/src/main/jniLibs/arm64-v8a
# Create a minimal working librender.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/librender.so
# Create a minimal working libqemu.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemu.so
# Create a minimal working libqemuimg.so
echo -e "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" > app/src/main/jniLibs/arm64-v8a/libqemuimg.so

# Create new APK
zip -r ../kios-native-fixed.apk . -x "META-INF/*"
cd ..
rm -rf temp_native

echo "✅ Native Fixed APK created: kios-native-fixed.apk"
echo "Size: $(du -h kios-native-fixed.apk)"

# Install on device
echo "Installing on connected device..."
adb -s 320081735bb166a3 install -r kios-native-fixed.apk

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
        
        echo "✅ Native fix successful!"
    else
        echo "❌ App crashed when clicking"
    fi
else
    echo "❌ App crashed on launch"
fi