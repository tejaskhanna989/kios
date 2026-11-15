#!/bin/bash

echo "=== Creating Fixed APK V3 ==="

# First, let's verify the current source code is clean
echo "Checking source code for Render.alive references..."
RENDER_ALIVE_COUNT=$(find app/src/main/java -name "*.java" -not -name "*.backup" -exec grep -l "Render\.alive" {} \; | wc -l)

if [ "$RENDER_ALIVE_COUNT" -gt 0 ]; then
    echo "❌ Found $RENDER_ALIVE_COUNT files with Render.alive references"
    exit 1
else
    echo "✅ No Render.alive references found in source code"
fi

# Check if we can use the existing CI-built APK as a base
if [ -f "kios-ci-working.apk" ]; then
    echo "Using kios-ci-working.apk as base..."
    
    # Extract the APK
    mkdir -p temp_fix_v3
    cd temp_fix_v3
    unzip -q ../kios-ci-working.apk
    
    # Check the classes.dex file
    if [ -f "classes.dex" ]; then
        # Check if it contains Render.alive references
        if strings classes.dex | grep -q "alive"; then
            echo "⚠️  classes.dex contains 'alive' references"
            echo "This APK needs to be rebuilt with fixed source code"
        else
            echo "✅ classes.dex does not contain 'alive' references"
            echo "This APK should work correctly"
            
            # Repackage the APK
            cd ..
            rm -rf temp_fix_v3
            
            # Create a copy with a new name
            cp kios-ci-working.apk kios-fixed-v3.apk
            echo "✅ Created kios-fixed-v3.apk"
            
            echo ""
            echo "To test this APK:"
            echo "adb uninstall com.kios.ios"
            echo "adb install -r kios-fixed-v3.apk"
            
            exit 0
        fi
    else
        echo "❌ classes.dex not found in extracted APK"
        cd ..
        rm -rf temp_fix_v3
        exit 1
    fi
else
    echo "❌ kios-ci-working.apk not found"
    exit 1
fi

# If we get here, we need to rebuild the APK
echo "Attempting to rebuild APK with fixed source code..."

# Try to use gradle if possible
if command -v gradle &> /dev/null || [ -f "gradlew" ]; then
    echo "Using gradle to build APK..."
    
    if [ -f "gradlew" ]; then
        ./gradlew clean assembleDebug --no-daemon
    else
        gradle clean assembleDebug --no-daemon
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ APK built successfully"
        cp app/build/outputs/apk/debug/app-debug.apk kios-fixed-v3.apk
        echo "✅ Created kios-fixed-v3.apk"
        
        echo ""
        echo "To test this APK:"
        echo "adb uninstall com.kios.ios"
        echo "adb install -r kios-fixed-v3.apk"
        
        exit 0
    else
        echo "❌ Gradle build failed"
        exit 1
    fi
else
    echo "❌ No gradle or gradlew found"
    exit 1
fi