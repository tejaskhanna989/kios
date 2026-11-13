#!/bin/bash

# Script to extract iOS 12.4.1 IPSW and get the exact file information
# for iPhone 8 (iPhone10,1)

set -e

# Configuration
IPSW_URL="https://updates.cdn-apple.com/2019SummerFCS/fullrestores/061-05179/A45E35B2-C4E7-11E9-9918-19610AD8B7A1/iPhone_4.7_12.4.1_16G102_Restore.ipsw"
IPSW_FILENAME="iPhone_4.7_12.4.1_16G102_Restore.ipsw"
EXTRACT_DIR="ios12_extract"

echo "=== iOS 12 IPSW Extractor ==="
echo "This will download and extract the iOS 12.4.1 IPSW for iPhone 8"
echo "IPSW URL: $IPSW_URL"
echo ""

# Check if we have the IPSW file
if [ ! -f "$IPSW_FILENAME" ]; then
    echo "Downloading iOS 12.4.1 IPSW (3GB)..."
    echo "This may take several minutes..."
    
    # Download with progress
    curl -L -# -o "$IPSW_FILENAME" "$IPSW_URL"
    
    # Verify download
    if [ ! -f "$IPSW_FILENAME" ]; then
        echo "ERROR: Download failed!"
        exit 1
    fi
    
    echo "Download complete: $IPSW_FILENAME"
else
    echo "Using existing IPSW file: $IPSW_FILENAME"
fi

# Verify file size (should be around 3GB)
FILE_SIZE=$(stat -c%s "$IPSW_FILENAME")
echo "File size: $FILE_SIZE bytes ($((FILE_SIZE/1024/1024)) MB)"

# Create extraction directory
mkdir -p "$EXTRACT_DIR"
cd "$EXTRACT_DIR"

# Extract IPSW (it's a ZIP file)
echo "Extracting IPSW..."
unzip -q "../$IPSW_FILENAME"

echo ""
echo "=== IPSW Contents ==="
echo "Key files found:"
echo ""

# Find and list important files
echo "=== BuildManifest.plist ==="
find . -name "BuildManifest.plist" -exec ls -lh {} \;

echo ""
echo "=== Device Trees ==="
find . -name "*DeviceTree*" -exec ls -lh {} \;

echo ""
echo "=== Kernel Caches ==="
find . -name "*kernelcache*" -exec ls -lh {} \;

echo ""
echo "=== OS Images (.dmg files) ==="
find . -name "*.dmg" -exec ls -lh {} \; | sort -k5 -hr

echo ""
echo "=== Trust Cache files ==="
find . -name "*.trustcache" -exec ls -lh {} \;

echo ""
echo "=== Firmware Directory ==="
find ./Firmware -type f -name "*.im4p" | head -10 | xargs ls -lh

echo ""
echo "=== Calculating CRC-32 for key files ==="
echo "This may take a moment..."

# Calculate CRC-32 for important files
for file in $(find . -name "DeviceTree.j97ap.im4p" -o -name "*.dmg" | head -5); do
    if [ -f "$file" ]; then
        crc=$(crc32 "$file" 2>/dev/null || echo "CRC32 not available")
        size=$(stat -c%s "$file")
        echo "$file: $size bytes, CRC32: $crc"
    fi
done

echo ""
echo "=== Summary ==="
echo "Please provide me with these details:"
echo "1. Exact filename of the OS .dmg file (should be ~2GB)"
echo "2. Exact filename of the DeviceTree file"
echo "3. Exact filename of the kernelcache file"
echo "4. File sizes and CRC-32 values (if calculated)"

echo ""
echo "=== Ready to update asoft-setup.json ==="
echo "Run this command to create the updated setup file:"
echo "./update-setup-ios12.sh"