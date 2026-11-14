#!/bin/bash

# Complete automated iOS 12 installation for Kios
set -e

echo "=== Complete Automated iOS 12 Installation ==="

# Check if device is connected
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ No device connected!"
    exit 1
fi

echo "Device ID: $DEVICE_ID"

# Step 1: Install Termux and required packages
echo "Step 1: Installing Termux and build tools..."
adb -s $DEVICE_ID shell "am force-stop com.termux || true"
adb -s $DEVICE_ID shell "pm uninstall com.termux || true"
adb -s $DEVICE_ID shell "am start -n com.android.packageinstaller/.PackageInstallerActivity -d 'market://details?id=com.termux'" || true

echo "Please install Termux from the market, then press Enter to continue..."
read -p ""

# Step 2: Install required packages in Termux
echo "Step 2: Installing required packages..."
adb -s $DEVICE_ID shell "input tap 500 1000" # Tap install button
sleep 3
adb -s $DEVICE_ID shell "input tap 500 1200" # Tap open button
sleep 3
adb -s $DEVICE_ID shell "input text 'pkg update && pkg install clang git make python libslirp pixman'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 10

# Step 3: Build QEMU
echo "Step 3: Building QEMU..."
adb -s $DEVICE_ID shell "input text 'git clone https://github.com/tejaskhanna989/qemu-sptm.git'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 5
adb -s $DEVICE_ID shell "input text 'cd qemu-sptm'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 3
adb -s $DEVICE_ID shell "input text 'git checkout asoft-android'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 3
adb -s $DEVICE_ID shell "input text './configure --target-list=aarch64-softmmu --disable-system --enable-user --disable-capstone --disable-slirp'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 3
adb -s $DEVICE_ID shell "input text 'make -j\$(nproc)'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 30

# Step 4: Copy libraries to APK
echo "Step 4: Copying libraries to APK..."
adb -s $DEVICE_ID shell "input text './pull-libs.sh /data/data/com.termux/files/home/qemu-sptm/qemu-system-aarch64'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 10

# Step 5: Build and install Kios
echo "Step 5: Building and installing Kios..."
adb -s $DEVICE_ID shell "input text 'cd /sdcard/Download && unzip kios.zip'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 5
adb -s $DEVICE_ID shell "input text 'cd kios && ./gradlew assembleDebug'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 10
adb -s $DEVICE_ID shell "input text 'adb install app/build/outputs/apk/debug/app-debug.apk'"
adb -s $DEVICE_ID shell "input tap 500 1400" # Tap execute button
sleep 5

echo "✅ Complete installation finished!"
echo "Kios with iOS 12 is now ready to use!"