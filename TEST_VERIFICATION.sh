#!/bin/bash

# Test verification script for Kios
# Run this to verify your setup is ready for testing

echo "=== Kios Test Verification ==="
echo ""

# Check if we're in the right directory
if [ ! -f "app/build.gradle" ]; then
    echo "❌ ERROR: Not in the Kios project directory!"
    echo "Please run this script from the kios folder."
    exit 1
fi

echo "✅ Found Kios project"
echo ""

# Check for required files
echo "Checking required files..."
files=(
    "app/build.gradle"
    "app/src/main/java/com/kios/ios/Guest.java"
    "setup/asoft-setup.json"
    "extract-ios12.sh"
    "update-setup-ios12.sh"
    "TESTING_GUIDE.md"
    "M30_TEST_CHECKLIST.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
    fi
done
echo ""

# Check if scripts are executable
echo "Checking script permissions..."
if [ -x "extract-ios12.sh" ]; then
    echo "✅ extract-ios12.sh is executable"
else
    echo "❌ extract-ios12.sh needs execute permission"
    echo "Run: chmod +x extract-ios12.sh"
fi

if [ -x "update-setup-ios12.sh" ]; then
    echo "✅ update-setup-ios12.sh is executable"
else
    echo "❌ update-setup-ios12.sh needs execute permission"
    echo "Run: chmod +x update-setup-ios12.sh"
fi

if [ -x "BUILD_SCRIPT.sh" ]; then
    echo "✅ BUILD_SCRIPT.sh is executable"
else
    echo "❌ BUILD_SCRIPT.sh needs execute permission"
    echo "Run: chmod +x BUILD_SCRIPT.sh"
fi
echo ""

# Check for Android tools
echo "Checking Android tools..."
if command -v adb &> /dev/null; then
    echo "✅ ADB found"
else
    echo "❌ ADB not found - Install Android Platform Tools"
fi

if command -v gradle &> /dev/null; then
    echo "✅ Gradle found"
else
    echo "⚠️  Gradle not found - Using ./gradlew wrapper"
fi
echo ""

# Check if we can build
echo "Testing build process..."
if ./gradlew tasks --quiet > /dev/null 2>&1; then
    echo "✅ Gradle build system works"
else
    echo "❌ Gradle build system failed"
    echo "Check Android SDK installation"
fi
echo ""

# Summary
echo "=== Summary ==="
echo ""
echo "Ready to test Kios on your M30?"
echo ""
echo "Next steps:"
echo "1. Run: ./BUILD_SCRIPT.sh"
echo "2. Run: ./extract-ios12.sh"
echo "3. Follow M30_TEST_CHECKLIST.md"
echo ""
echo "Good luck! 🍎✨"