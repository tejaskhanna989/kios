#!/bin/bash

echo "=== Local Build Attempt ==="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf app/build/
rm -f kios-local-build.apk

# Try to build with gradle wrapper
echo "Attempting to build with gradle wrapper..."
if [ -f "gradlew" ]; then
    echo "Using gradlew..."
    ./gradlew clean assembleDebug --no-daemon --stacktrace
    
    if [ $? -eq 0 ]; then
        echo "✅ Build successful!"
        cp app/build/outputs/apk/debug/app-debug.apk kios-local-build.apk
        echo "✅ APK created: kios-local-build.apk"
        
        # Try to install on device
        echo "Installing on device..."
        adb uninstall com.kios.ios
        adb install -r kios-local-build.apk
        
        if [ $? -eq 0 ]; then
            echo "✅ Installation successful!"
            adb shell am start -n com.kios.ios/.MainActivity
            
            # Wait and check for crashes
            sleep 5
            echo "Checking for crashes..."
            CRASH_COUNT=$(adb logcat -d | grep -E "(crash|exception)" | grep -i kios | wc -l)
            
            if [ "$CRASH_COUNT" -eq 0 ]; then
                echo "✅ No crashes detected! App is working!"
            else
                echo "⚠️  $CRASH_COUNT crash(es) detected"
                adb logcat -d | grep -E "(crash|exception)" | grep -i kios | tail -3
            fi
        else
            echo "❌ Installation failed"
        fi
    else
        echo "❌ Build failed"
        exit 1
    fi
else
    echo "❌ gradlew not found"
    exit 1
fi