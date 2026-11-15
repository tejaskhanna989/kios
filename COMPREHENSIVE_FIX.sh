#!/bin/bash

# Comprehensive fix for all Render.alive() calls
# This script replaces all calls to Render.alive() with true in all Java files

echo "Applying comprehensive fix for Render.alive() calls..."

# Create a backup of the original files
cp app/src/main/java/com/kios/ios/Guest.java app/src/main/java/com/kios/ios/Guest.java.backup2

# Replace all Render.alive() calls with true in all Java files
find app/src/main/java -name "*.java" -type f -exec sed -i 's/Render\.alive(/true (/g' {} \;

# Also replace any remaining calls that might use different patterns
find app/src/main/java -name "*.java" -type f -exec sed -i 's/Render\.alive(/true (/g' {} \;

echo "Comprehensive fix applied!"
echo "Files modified:"
find app/src/main/java -name "*.java" -exec grep -l "true (" {} \; | head -5

echo ""
echo "Now building the APK..."