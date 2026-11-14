#!/bin/bash

# Complete automated cleanup for Kios
set -e

echo "=== Complete Automated Cleanup ==="

# Check if device is connected
DEVICE_ID=$(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ No device connected!"
    exit 1
fi

echo "Device ID: $DEVICE_ID"

# Step 1: Uninstall Kios
echo "Step 1: Uninstalling Kios..."
adb -s $DEVICE_ID shell "am force-stop com.kios.ios"
adb -s $DEVICE_ID shell "pm uninstall com.kios.ios"

# Step 2: Remove QEMU build
echo "Step 2: Removing QEMU build..."
adb -s $DEVICE_ID shell "rm -rf /data/data/com.termux/files/home/qemu-sptm"

# Step 3: Remove Termux
echo "Step 3: Removing Termux..."
adb -s $DEVICE_ID shell "am force-stop com.termux"
adb -s $DEVICE_ID shell "pm uninstall com.termux"

# Step 4: Clean up temporary files
echo "Step 4: Cleaning up temporary files..."
adb -s $DEVICE_ID shell "rm -rf /data/local/tmp/kios-fix"
adb -s $DEVICE_ID shell "rm -rf /sdcard/Download/kios"
adb -s $DEVICE_ID shell "rm -rf /sdcard/Download/kios.zip"

echo "✅ Complete cleanup finished!"
echo "All Kios-related files have been removed!"