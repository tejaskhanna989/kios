#!/bin/bash

# Script to update asoft-setup.json with iOS 12 file information
# Run after extract-ios12.sh

set -e

# Configuration
EXTRACT_DIR="ios12_extract"
SETUP_FILE="setup/asoft-setup.json"

echo "=== Updating iOS 12 setup configuration ==="
echo ""

# Check if extraction directory exists
if [ ! -d "$EXTRACT_DIR" ]; then
    echo "ERROR: iOS 12 extraction directory not found!"
    echo "Run extract-ios12.sh first."
    exit 1
fi

# Find key files
OS_DMG=$(find "$EXTRACT_DIR" -name "*.dmg" | grep -v "trustcache" | sort -k5 -hr | head -1)
DEVICE_TREE=$(find "$EXTRACT_DIR" -name "*DeviceTree*" | head -1)
KERNEL_CACHE=$(find "$EXTRACT_DIR" -name "*kernelcache*" | head -1)

if [ -z "$OS_DMG" ] || [ -z "$DEVICE_TREE" ] || [ -z "$KERNEL_CACHE" ]; then
    echo "ERROR: Could not find required iOS 12 files!"
    echo "OS DMG: $OS_DMG"
    echo "Device Tree: $DEVICE_TREE"
    echo "Kernel Cache: $KERNEL_CACHE"
    exit 1
fi

# Get file sizes
OS_SIZE=$(stat -c%s "$OS_DMG")
DEVICE_TREE_SIZE=$(stat -c%s "$DEVICE_TREE")
KERNEL_SIZE=$(stat -c%s "$KERNEL_CACHE")

# Calculate CRC-32 (if crc32 is available)
OS_CRC=$(crc32 "$OS_DMG" 2>/dev/null || echo "PLACEHOLDER")
DEVICE_TREE_CRC=$(crc32 "$DEVICE_TREE" 2>/dev/null || echo "PLACEHOLDER")
KERNEL_CRC=$(crc32 "$KERNEL_CACHE" 2>/dev/null || echo "PLACEHOLDER")

echo "Found files:"
echo "OS DMG: $OS_DMG ($OS_SIZE bytes)"
echo "Device Tree: $DEVICE_TREE ($DEVICE_TREE_SIZE bytes)"
echo "Kernel Cache: $KERNEL_CACHE ($KERNEL_SIZE bytes)"
echo ""

# Create temporary JSON update
cat > temp_ios12_update.json << EOF
{
  "ipsw": {
    "url": "https://updates.cdn-apple.com/2019SummerFCS/fullrestores/061-05179/A45E35B2-C4E7-11E9-9918-19610AD8B7A1/iPhone_4.7_12.4.1_16G102_Restore.ipsw",
    "bytes": 2900000000,
    "members": [
      {
        "name": "BuildManifest.plist",
        "role": "manifest",
        "bytes": 100000,
        "method": 8,
        "zipBytes": 50000,
        "crc32": "PLACEHOLDER"
      },
      {
        "name": "$(basename "$OS_DMG")",
        "role": "OS",
        "bytes": $OS_SIZE,
        "method": 0,
        "crc32": "$OS_CRC"
      },
      {
        "name": "$(basename "$DEVICE_TREE")",
        "role": "devicetree",
        "bytes": $DEVICE_TREE_SIZE,
        "method": 8,
        "zipBytes": $DEVICE_TREE_SIZE,
        "crc32": "$DEVICE_TREE_CRC"
      },
      {
        "name": "$(basename "$KERNEL_CACHE")",
        "role": "kernelcache",
        "bytes": $KERNEL_SIZE,
        "method": 8,
        "zipBytes": $KERNEL_SIZE,
        "crc32": "$KERNEL_CRC"
      }
    ],
    "note": "iPhone 8 (iPhone10,1) iOS 12.4.1 (16G102) - extracted from IPSW"
  }
}
EOF

# Update the setup file
echo "Updating $SETUP_FILE..."
python3 -c "
import json

# Load the existing setup file
with open('$SETUP_FILE', 'r') as f:
    setup = json.load(f)

# Load the iOS 12 update
with open('temp_ios12_update.json', 'r') as f:
    ios12_update = json.load(f)

# Update the iOS 12 section
setup['os']['ios12'] = ios12_update['ipsw']

# Write back to the file
with open('$SETUP_FILE', 'w') as f:
    json.dump(setup, f, indent=2)

print('Setup file updated successfully!')
"

# Clean up
rm temp_ios12_update.json

echo ""
echo "=== Next steps ==="
echo "1. Commit the updated setup file:"
echo "   git add $SETUP_FILE"
echo "   git commit -m 'Add iOS 12 file information from IPSW extraction'"
echo "   git push"
echo ""
echo "2. Build and test on your M30:"
echo "   ./gradlew assembleDebug"
echo "   adb install app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "3. Open the app and try to set up iOS 12"