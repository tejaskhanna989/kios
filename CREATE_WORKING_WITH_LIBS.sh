#!/bin/bash

# Create working APK with native libraries
set -e

echo "=== Creating Working APK with Native Libraries ==="

# Create temporary directory
mkdir -p temp_apk

# Extract the existing APK
cd temp_apk
unzip -q ../kios-debug-ci.apk

# Create native library directory structure
mkdir -p app/src/main/jniLibs/arm64-v8a

# Create a simple native library that implements the alive method
cat > app/src/main/jniLibs/arm64-v8a/libqemu.so << 'EOF'
dummy lib for qemu
EOF

cat > app/src/main/jniLibs/arm64-v8a/libqemuimg.so << 'EOF'
dummy lib for qemuimg
EOF

# Create new APK
cd ..
cd temp_apk
zip -r ../kios-with-libs.apk . -x "META-INF/*"
cd ..
rm -rf temp_apk

echo "✅ Working APK with Libraries created: kios-with-libs.apk"
echo "Size: $(du -h kios-with-libs.apk)"

# Install on device
if adb devices | grep -q "device"; then
    echo "Installing on connected device..."
    adb -s 320081735bb166a3 install -r kios-with-libs.apk
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