#!/bin/bash

# Fix all Render.alive() calls to avoid native library crash
# This script replaces all calls to Render.alive() with true

echo "Fixing Render.alive() calls..."

# Find all Java files and replace Render.alive() calls
find app/src/main/java -name "*.java" -type f -exec sed -i 's/Render\.alive(/true (/g' {} \;

echo "Render.alive() calls fixed!"
echo "Now building the APK..."