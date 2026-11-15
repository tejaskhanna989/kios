#!/bin/bash

# Create a working APK with fixed Render.alive calls
echo "=== Creating Working APK V2 ==="

# Try to set up Android SDK environment
export ANDROID_SDK_ROOT=/usr/local/android-sdk
export ANDROID_NDK_ROOT=/usr/local/android-ndk

# Create a simple workaround for the SDK issue
if [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "Android SDK not found, creating minimal workaround..."
    
    # Create a minimal local.properties file
    cat > local.properties << EOF
sdk.dir=/usr/local/android-sdk
EOF
    
    # Try to use the gradle wrapper directly
    echo "Attempting to build with gradle wrapper..."
    ./gradlew clean assembleDebug --no-daemon --offline --stacktrace
    
    if [ $? -eq 0 ]; then
        echo "Build successful!"
        cp app/build/outputs/apk/debug/app-debug.apk kios-working-v2.apk
        echo "Working APK created: kios-working-v2.apk"
    else
        echo "Gradle build failed, trying alternative approach..."
        
        # Try to use one of the existing build scripts
        if [ -f "BUILD_FIXED_APK.sh" ]; then
            ./BUILD_FIXED_APK.sh
        else
            echo "No working build script found"
            exit 1
        fi
    fi
else
    echo "Android SDK found, building with it..."
    ./gradlew clean assembleDebug --no-daemon --stacktrace
    
    if [ $? -eq 0 ]; then
        echo "Build successful!"
        cp app/build/outputs/apk/debug/app-debug.apk kios-working-v2.apk
        echo "Working APK created: kios-working-v2.apk"
    else
        echo "Build failed!"
        exit 1
    fi
fi