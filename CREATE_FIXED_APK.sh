#!/bin/bash

# Create a fixed APK by using the existing build system
echo "Creating fixed APK..."

# Try to use the gradle build system with a workaround for the SDK issue
export ANDROID_SDK_ROOT=/usr/local/android-sdk
export ANDROID_NDK_ROOT=/usr/local/android-ndk

# If the SDK is not available, try to use the gradle wrapper directly
if [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "Android SDK not found, trying to build without it..."
    ./gradlew clean assembleDebug --no-daemon --offline --stacktrace
else
    echo "Android SDK found, building with it..."
    ./gradlew clean assembleDebug --no-daemon --stacktrace
fi

# Check if the build was successful
if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "Build successful!"
    cp app/build/outputs/apk/debug/app-debug.apk kios-fixed-debug.apk
    echo "Fixed APK created: kios-fixed-debug.apk"
else
    echo "Build failed, trying alternative approach..."
    # Try to use one of the existing build scripts
    if [ -f "BUILD_FIXED_APK.sh" ]; then
        ./BUILD_FIXED_APK.sh
    else
        echo "No working build script found"
        exit 1
    fi
fi