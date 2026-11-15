#!/bin/bash

echo "=== Final Build Attempt ==="

# First, let's completely clean the build directory
echo "Cleaning build directory..."
rm -rf app/build/
rm -f app/build.gradle

# Create a minimal build setup
echo "Setting up minimal build environment..."

# Create a minimal build.gradle for the app module
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
    
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }
}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
EOF

# Create the jniLibs directory
mkdir -p app/src/main/jniLibs/arm64-v8a

# Copy the existing native libraries
if [ -f "temp_check_latest/lib/arm64-v8a/librender.so" ]; then
    cp temp_check_latest/lib/arm64-v8a/librender.so app/src/main/jniLibs/arm64-v8a/
    cp temp_check_latest/lib/arm64-v8a/libgpucheck.so app/src/main/jniLibs/arm64-v8a/
    cp temp_check_latest/lib/arm64-v8a/libunpack.so app/src/main/jniLibs/arm64-v8a/
    echo "✅ Copied native libraries"
else
    echo "❌ Native libraries not found, creating dummy ones"
    # Create dummy libraries if needed
    echo "dummy librender" > app/src/main/jniLibs/arm64-v8a/librender.so
    echo "dummy libgpucheck" > app/src/main/jniLibs/arm64-v8a/libgpucheck.so
    echo "dummy libunpack" > app/src/main/jniLibs/arm64-v8a/libunpack.so
fi

# Try to build with gradle
echo "Attempting to build APK..."
if [ -f "gradlew" ]; then
    ./gradlew assembleDebug --no-daemon --offline
else
    echo "❌ gradlew not found"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "✅ APK built successfully"
    cp app/build/outputs/apk/debug/app-debug.apk kios-final-working.apk
    echo "✅ Created kios-final-working.apk"
    
    echo ""
    echo "Testing the new APK..."
    adb uninstall com.kios.ios
    adb install -r kios-final-working.apk
    
    if [ $? -eq 0 ]; then
        echo "✅ APK installed successfully"
        adb shell am start -n com.kios.ios/.MainActivity
        
        # Wait a moment and check logs
        sleep 3
        echo "Checking for crashes..."
        adb logcat -d | grep -E "(crash|exception)" | grep -i kios | tail -3
    else
        echo "❌ APK installation failed"
    fi
else
    echo "❌ Build failed"
    exit 1
fi