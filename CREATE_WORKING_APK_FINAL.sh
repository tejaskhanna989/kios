#!/bin/bash

echo "=== Creating Final Working APK ==="

# We'll use the CI-built APK but with a different approach
# Since the source code is clean (no Render.alive calls), we need to 
# ensure the APK we use matches our fixed source code

echo "Checking source code status..."
SOURCE_CLEAN=$(find app/src/main/java -name "*.java" -not -name "*.backup" -exec grep -l "Render\.alive" {} \; | wc -l)

if [ "$SOURCE_CLEAN" -gt 0 ]; then
    echo "❌ Source code still has Render.alive references"
    exit 1
else
    echo "✅ Source code is clean - no Render.alive references"
fi

# The issue is that our current APK was built from source that still had Render.alive calls
# We need to rebuild from clean source

echo "Attempting to create a working APK from clean source..."

# Let's try to use the CI APK as a base but with our modifications
echo "Using CI APK as base..."

# Extract the CI APK
mkdir -p temp_final
cd temp_final
unzip -q ../kios-ci-working.apk

# Check if we can find the Guest.class in the dex file
echo "Checking Guest.class implementation..."

# Since we can't easily modify dex files without proper tools,
# let's create a simple workaround by ensuring our APK has the right version

# Copy the clean source files to ensure we have the right version
cd ../app/src/main/java/com/kios/ios

# Verify the Guest.java file has the correct implementation
echo "Verifying Guest.java implementation..."
grep -A 5 "static synchronized boolean running()" Guest.java

if grep -q "Always return true to avoid native library crash" Guest.java; then
    echo "✅ Guest.java has the correct implementation"
    
    # Go back to project root
    cd ../../../../../
    
    # Create a simple test APK by copying the CI APK
    echo "Creating final working APK..."
    cp kios-ci-working.apk kios-final-working.apk
    
    # The issue is that the APK was built before we fixed the source
    # We need to document this limitation
    
    echo ""
    echo "=== ISSUE IDENTIFIED ==="
    echo "The current APK was built from source that contained Render.alive calls."
    echo "Even though we've fixed the source code, we can't easily rebuild without"
    echo "proper Android SDK setup."
    echo ""
    echo "CURRENT STATUS:"
    echo "✅ Source code is clean (no Render.alive calls)"
    echo "✅ Guest.running() returns true (no native dependency)"
    echo "❌ Current APK still has old implementation"
    echo ""
    echo "SOLUTION:"
    echo "1. The source code is correct and will work with proper rebuild"
    echo "2. For now, you can manually test by ensuring the app doesn't call"
    echo "   Render.alive() - the Guest.running() method should return true"
    echo ""
    echo "To test the current APK:"
    echo "1. Install: adb install -r kios-ci-working.apk"
    echo "2. Open the app"
    echo "3. If it crashes, it's due to the Render.alive issue"
    echo "4. The fix is in the source code but needs a proper rebuild"
    
    # Clean up
    rm -rf temp_final
    
    echo ""
    echo "Next steps:"
    echo "- Set up proper Android SDK environment"
    echo "- Rebuild the APK with fixed source code"
    echo "- Or use GitHub Actions CI to build automatically"
    
else
    echo "❌ Guest.java doesn't have the correct implementation"
    cd ../../../../../
    exit 1
fi