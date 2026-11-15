#!/bin/bash

echo "=== Fixing Gradle Configuration ==="

# First, let's revert to a simpler build configuration
echo "Restoring original build.gradle files..."

# Restore the original project build.gradle
cat > build.gradle << 'EOF'
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    id 'com.android.application' version '8.1.4' apply false
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
EOF

# Restore the original app build.gradle
cat > app/build.gradle << 'EOF'
apply plugin: 'com.android.application'

android {
    compileSdkVersion 34
    buildToolsVersion "34.0.0"

    defaultConfig {
        applicationId "com.kios.ios"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            minifyEnabled false
        }
    }
}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
EOF

echo "✅ Restored original build configuration"

# Clean the build directory
echo "Cleaning build directory..."
rm -rf app/build/
rm -f .gradle/

# Try to build again
echo "Attempting to build with fixed configuration..."
./gradlew clean assembleDebug --no-daemon --offline

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    cp app/build/outputs/apk/debug/app-debug.apk kios-fixed.apk
    echo "✅ APK created: kios-fixed.apk"
    
    # Try to install on device
    echo "Installing on device..."
    adb uninstall com.kios.ios
    adb install -r kios-fixed.apk
    
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
    echo "❌ Build failed again"
    exit 1
fi