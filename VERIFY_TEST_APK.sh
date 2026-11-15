#!/bin/bash

echo "=== Verifying Test APK ==="

if [ ! -f "kios-test-fixed.apk" ]; then
    echo "Error: kios-test-fixed.apk not found"
    exit 1
fi

echo "Extracting APK for verification..."
mkdir -p temp_verify
cd temp_verify
unzip -q ../kios-test-fixed.apk

echo "Checking native libraries..."
if [ -d "lib/arm64-v8a" ]; then
    echo "Native libraries found:"
    ls -la lib/arm64-v8a/
    echo ""
fi

echo "Checking if librender.so exists..."
if [ -f "lib/arm64-v8a/librender.so" ]; then
    echo "✓ librender.so found"
    
    # Check if it's a dummy library (small size)
    SIZE=$(stat -c%s lib/arm64-v8a/librender.so)
    if [ "$SIZE" -lt 100000 ]; then
        echo "✓ librender.so appears to be a dummy/fixed library (size: $SIZE bytes)"
    else
        echo "⚠ librender.so is large ($SIZE bytes), may be a real library"
    fi
else
    echo "✗ librender.so not found"
fi

echo ""
echo "Checking classes.dex for Render.alive references..."
if [ -f "classes.dex" ]; then
    if strings classes.dex | grep -q "alive"; then
        echo "⚠ Found 'alive' references in classes.dex"
        echo "This may indicate the Render.alive issue is not fully fixed"
    else
        echo "✓ No 'alive' references found in classes.dex"
    fi
else
    echo "✗ classes.dex not found"
fi

cd ..
rm -rf temp_verify

echo ""
echo "Verification complete. APK ready for testing."
